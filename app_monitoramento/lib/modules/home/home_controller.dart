import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'domain/link_reading.dart';
import 'domain/mesh_connection_status.dart';
import 'domain/mesh_constants.dart';
import 'domain/telemetry_message.dart';
import 'services/endpoint_normalizer.dart';
import 'services/rssi_analyzer.dart';
import 'services/telemetry_parser.dart';

class HomeController extends GetxController {
  HomeController({
    this.autoConnect = true,
    this.parser = const TelemetryParser(),
    this.analyzer = const RssiAnalyzer(),
    this.endpointNormalizer = const EndpointNormalizer(),
  });

  final bool autoConnect;
  final TelemetryParser parser;
  final RssiAnalyzer analyzer;
  final EndpointNormalizer endpointNormalizer;
  final endpointController = TextEditingController(
    text: MeshConstants.defaultEndpoint,
  );
  final endpoint = MeshConstants.defaultEndpoint.obs;
  final connectionStatus = MeshConnectionStatus.disconnected.obs;
  final statusAlarme = false.obs;
  final activeZone = ''.obs;
  final lastMessage = 'Aguardando telemetria'.obs;
  final errorMessage = ''.obs;
  final matrix = List<int?>.filled(25, null).obs;
  final baselineLinks = List<int?>.filled(
    MeshConstants.linkNames.length,
    null,
  ).obs;
  final baselineNoise = List<double>.filled(
    MeshConstants.linkNames.length,
    MeshConstants.defaultNoiseFloor,
  ).obs;
  final quadrantScores = List<double>.filled(4, 0).obs;
  final quadrantConfidence = 0.0.obs;
  final activeQuadrant = (-1).obs;
  final regionUncertain = false.obs;
  final quadrantProfiles = List<List<double>?>.filled(4, null).obs;
  final trainedQuadrant = (-1).obs;
  final trainingProgress = 0.0.obs;
  final matrixCount = 0.obs;
  final alertCount = 0.obs;
  final isCalibrating = false.obs;
  final isTraining = false.obs;
  final calibrationProgress = 0.0.obs;
  final lastUpdate = Rxn<DateTime>();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _alertTimer;
  List<int> _calibrationTotals = List<int>.filled(
    MeshConstants.linkNames.length,
    0,
  );
  List<int> _calibrationSquares = List<int>.filled(
    MeshConstants.linkNames.length,
    0,
  );
  List<int> _calibrationCounts = List<int>.filled(
    MeshConstants.linkNames.length,
    0,
  );
  List<double> _trainingTotals = List<double>.filled(
    MeshConstants.linkNames.length,
    0,
  );
  int _calibrationSamples = 0;
  int _trainingSamples = 0;
  int _pendingQuadrant = -1;
  int _pendingQuadrantFrames = 0;
  DateTime? _quadrantHoldUntil;

  @override
  void onInit() {
    super.onInit();
    if (autoConnect) {
      conectarWebSocket();
    }
  }

  void conectarWebSocket([String? rawEndpoint]) {
    final url = endpointNormalizer.normalize(
      rawEndpoint ?? endpointController.text,
    );
    endpoint.value = url;
    endpointController.text = url;
    errorMessage.value = '';
    connectionStatus.value = MeshConnectionStatus.connecting;

    _closeChannel();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      connectionStatus.value = MeshConnectionStatus.connected;
      lastMessage.value = 'Conectado em $url';
      _subscription = channel.stream.listen(
        (mensagem) {
          _handleMessage(mensagem.toString());
        },
        onError: (erro) {
          errorMessage.value = 'Erro de conexao: $erro';
          connectionStatus.value = MeshConnectionStatus.error;
        },
        onDone: () {
          if (connectionStatus.value != MeshConnectionStatus.error) {
            connectionStatus.value = MeshConnectionStatus.disconnected;
          }
        },
      );
    } catch (erro) {
      errorMessage.value = 'Endpoint invalido: $erro';
      connectionStatus.value = MeshConnectionStatus.error;
    }
  }

  void desconectar() {
    _closeChannel();
    connectionStatus.value = MeshConnectionStatus.disconnected;
    lastMessage.value = 'Desconectado';
  }

  void dispararAlarme() {
    statusAlarme.value = true;

    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 4), () {
      statusAlarme.value = false;
      activeZone.value = '';
    });
  }

  void calibrarAmbienteVazio() {
    isTraining.value = false;
    trainedQuadrant.value = -1;
    _calibrationTotals = List<int>.filled(MeshConstants.linkNames.length, 0);
    _calibrationSquares = List<int>.filled(MeshConstants.linkNames.length, 0);
    _calibrationCounts = List<int>.filled(MeshConstants.linkNames.length, 0);
    _calibrationSamples = 0;
    baselineLinks.assignAll(
      List<int?>.filled(MeshConstants.linkNames.length, null),
    );
    baselineNoise.assignAll(
      List<double>.filled(
        MeshConstants.linkNames.length,
        MeshConstants.defaultNoiseFloor,
      ),
    );
    quadrantScores.assignAll(List<double>.filled(4, 0));
    quadrantConfidence.value = 0;
    activeQuadrant.value = -1;
    regionUncertain.value = false;
    _pendingQuadrant = -1;
    _pendingQuadrantFrames = 0;
    _quadrantHoldUntil = null;
    calibrationProgress.value = 0;
    isCalibrating.value = true;
    lastMessage.value = 'Calibrando ambiente vazio...';
  }

  void treinarQuadrante(int index) {
    if (!hasBaseline ||
        index < 0 ||
        index >= MeshConstants.quadrantLabels.length) {
      return;
    }
    isCalibrating.value = false;
    isTraining.value = true;
    trainedQuadrant.value = index;
    trainingProgress.value = 0;
    _trainingSamples = 0;
    _trainingTotals = List<double>.filled(MeshConstants.linkNames.length, 0);
    lastMessage.value = 'Treinando ${MeshConstants.quadrantLabels[index]}...';
  }

  List<LinkReading> get links => analyzer.linksFromMatrix(matrix);

  int get validReadingCount => analyzer.validReadingCount(matrix);

  bool get hasBaseline => baselineLinks.any((value) => value != null);

  List<double?> get linkDeltas => analyzer.deltas(links, baselineLinks);

  List<double?> get linkSignals => analyzer.signals(linkDeltas, baselineNoise);

  double get strongestDelta {
    final values = linkDeltas.whereType<double>();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double get strongestSignal {
    final values = linkSignals.whereType<double>();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get hasMovement {
    if (!hasBaseline) return false;
    return analyzer.hasMovement(deltas: linkDeltas, signals: linkSignals);
  }

  bool get shouldHighlightQuadrant => hasBaseline && activeQuadrant.value >= 0;

  int get activeQuadrantIndex => hasBaseline ? activeQuadrant.value : -1;

  String get activeQuadrantLabel {
    final index = activeQuadrantIndex;
    if (!hasBaseline) return 'Sem baseline';
    if (index < 0) return 'Sem regiao dominante';
    return MeshConstants.quadrantLabels[index];
  }

  String get detectionLabel {
    if (!hasBaseline) return 'Calibre primeiro';
    if (shouldHighlightQuadrant) return activeQuadrantLabel;
    if (hasMovement || regionUncertain.value) return 'Regiao incerta';
    return 'Sem movimento';
  }

  bool get hasAnyProfile => quadrantProfiles.any((profile) => profile != null);

  bool isQuadrantTrained(int index) {
    return index >= 0 &&
        index < quadrantProfiles.length &&
        quadrantProfiles[index] != null;
  }

  String get connectionLabel {
    switch (connectionStatus.value) {
      case MeshConnectionStatus.connecting:
        return 'Conectando';
      case MeshConnectionStatus.connected:
        return 'Conectado';
      case MeshConnectionStatus.error:
        return 'Erro';
      case MeshConnectionStatus.disconnected:
        return 'Desconectado';
    }
  }

  void _handleMessage(String message) {
    lastMessage.value = message;
    lastUpdate.value = DateTime.now();

    switch (parser.parse(message)) {
      case MovementTelemetryMessage():
        alertCount.value++;
        activeZone.value = '';
        dispararAlarme();
      case ZoneAlertTelemetryMessage(:final zone):
        alertCount.value++;
        activeZone.value = zone;
        dispararAlarme();
      case MatrixTelemetryMessage(:final values):
        matrix.assignAll(values);
        matrixCount.value++;
        _captureCalibrationSample();
        _captureTrainingSample();
        _updateQuadrantScores();
      case InvalidTelemetryMessage(:final error):
        errorMessage.value = error;
      case UnknownTelemetryMessage():
        break;
    }
  }

  void _captureCalibrationSample() {
    if (!isCalibrating.value) return;

    final currentLinks = links;
    for (var i = 0; i < currentLinks.length; i++) {
      final value = currentLinks[i].rssi;
      if (value == null) continue;
      _calibrationTotals[i] += value;
      _calibrationSquares[i] += value * value;
      _calibrationCounts[i]++;
    }

    _calibrationSamples++;
    calibrationProgress.value =
        (_calibrationSamples / MeshConstants.targetCalibrationSamples).clamp(
          0,
          1,
        );

    if (_calibrationSamples >= MeshConstants.targetCalibrationSamples) {
      final result = analyzer.calibrationResult(
        totals: _calibrationTotals,
        squares: _calibrationSquares,
        counts: _calibrationCounts,
      );
      baselineLinks.assignAll(result.baseline);
      baselineNoise.assignAll(result.noise);
      isCalibrating.value = false;
      lastMessage.value = 'Baseline definida com $_calibrationSamples amostras';
      _updateQuadrantScores();
    }
  }

  void _captureTrainingSample() {
    if (!isTraining.value || trainedQuadrant.value < 0) return;

    final signals = linkSignals;
    for (var i = 0; i < signals.length; i++) {
      _trainingTotals[i] += signals[i] ?? 0;
    }

    _trainingSamples++;
    trainingProgress.value =
        (_trainingSamples / MeshConstants.targetTrainingSamples).clamp(0, 1);

    if (_trainingSamples >= MeshConstants.targetTrainingSamples) {
      final profile = List<double>.generate(
        MeshConstants.linkNames.length,
        (index) => _trainingTotals[index] / _trainingSamples,
      );
      final profiles = quadrantProfiles.toList();
      profiles[trainedQuadrant.value] = profile;
      quadrantProfiles.assignAll(profiles);
      lastMessage.value =
          'Perfil salvo: ${MeshConstants.quadrantLabels[trainedQuadrant.value]}';
      isTraining.value = false;
      trainedQuadrant.value = -1;
      _updateQuadrantScores();
    }
  }

  void _updateQuadrantScores() {
    if (!hasBaseline) {
      quadrantScores.assignAll(List<double>.filled(4, 0));
      quadrantConfidence.value = 0;
      activeQuadrant.value = -1;
      regionUncertain.value = false;
      return;
    }

    final estimate = analyzer.estimateQuadrant(
      signals: linkSignals,
      noise: baselineNoise,
    );
    quadrantScores.assignAll(estimate.scores);
    quadrantConfidence.value = estimate.confidence;
    _updateDisplayedQuadrant(estimate);
  }

  void _updateDisplayedQuadrant(QuadrantEstimate estimate) {
    final movement = hasMovement;
    final now = DateTime.now();
    final holdUntil = _quadrantHoldUntil;
    final isHolding = holdUntil != null && now.isBefore(holdUntil);

    if (!movement) {
      regionUncertain.value = false;
      _pendingQuadrant = -1;
      _pendingQuadrantFrames = 0;
      if (!isHolding) {
        activeQuadrant.value = -1;
      }
      return;
    }

    if (!estimate.isConfident || estimate.index < 0) {
      _pendingQuadrant = -1;
      _pendingQuadrantFrames = 0;
      regionUncertain.value = activeQuadrant.value < 0;
      if (!isHolding && activeQuadrant.value >= 0) {
        activeQuadrant.value = -1;
      }
      return;
    }

    regionUncertain.value = false;
    final candidate = estimate.index;
    if (activeQuadrant.value < 0 || activeQuadrant.value == candidate) {
      _setActiveQuadrant(candidate, now);
      return;
    }

    if (isHolding) return;

    if (_pendingQuadrant == candidate) {
      _pendingQuadrantFrames++;
    } else {
      _pendingQuadrant = candidate;
      _pendingQuadrantFrames = 1;
    }

    if (_pendingQuadrantFrames >= MeshConstants.quadrantSwitchFrames) {
      _setActiveQuadrant(candidate, now);
    }
  }

  void _setActiveQuadrant(int index, DateTime now) {
    activeQuadrant.value = index;
    _pendingQuadrant = -1;
    _pendingQuadrantFrames = 0;
    _quadrantHoldUntil = now.add(
      const Duration(milliseconds: MeshConstants.quadrantHoldMs),
    );
  }

  void _closeChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void onClose() {
    _alertTimer?.cancel();
    _closeChannel();
    endpointController.dispose();
    super.onClose();
  }
}
