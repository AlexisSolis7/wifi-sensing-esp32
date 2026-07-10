import 'package:app_monitoramento/modules/home/domain/telemetry_message.dart';
import 'package:app_monitoramento/modules/home/services/rssi_analyzer.dart';
import 'package:app_monitoramento/modules/home/services/telemetry_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetryParser', () {
    const parser = TelemetryParser();

    test('parseia matriz com 25 valores', () {
      final message = parser.parse('MATRIX:${List.filled(25, -40).join(',')}');

      expect(message, isA<MatrixTelemetryMessage>());
      expect((message as MatrixTelemetryMessage).values, hasLength(25));
    });

    test('parseia alerta de zona', () {
      final message = parser.parse('ALERTA:ZONA_C');

      expect(message, isA<ZoneAlertTelemetryMessage>());
      expect((message as ZoneAlertTelemetryMessage).zone, 'C');
    });

    test('rejeita matriz incompleta', () {
      final message = parser.parse('MATRIX:-40,-41');

      expect(message, isA<InvalidTelemetryMessage>());
    });
  });

  group('RssiAnalyzer', () {
    const analyzer = RssiAnalyzer();

    test('calcula media bidirecional de um link', () {
      final matrix = List<int?>.filled(25, 0)
        ..[1] = -40
        ..[5] = -44;

      expect(analyzer.averageRssi(matrix, 0, 1), -42);
    });

    test('ignora valores invalidos no RSSI', () {
      final matrix = List<int?>.filled(25, 0)
        ..[1] = 0
        ..[5] = -44;

      expect(analyzer.averageRssi(matrix, 0, 1), -44);
    });

    test('calcula sinal util descontando ruido', () {
      final signals = analyzer.signals([6, null, 1], [2, 2, 2]);

      expect(signals, [4, null, 0]);
    });

    test('detecta movimento em modo sensivel', () {
      expect(
        analyzer.hasMovement(deltas: [3, null, 1], signals: [0, null, 0]),
        isTrue,
      );
      expect(
        analyzer.hasMovement(deltas: [1, null, 1], signals: [0.8, null, 0]),
        isTrue,
      );
      expect(
        analyzer.hasMovement(deltas: [2, null, 1], signals: [0.5, null, 0]),
        isFalse,
      );
    });

    test('estima quadrante por votacao geometrica dos links', () {
      final signals = List<double?>.filled(10, 0)..[6] = 5;
      final noise = List<double>.filled(10, 2);

      final estimate = analyzer.estimateQuadrant(
        signals: signals,
        noise: noise,
      );

      expect(estimate.index, 1);
      expect(estimate.isConfident, isTrue);
    });

    test('marca regiao incerta quando o link e ambiguo', () {
      final signals = List<double?>.filled(10, 0)..[0] = 5;
      final noise = List<double>.filled(10, 2);

      final estimate = analyzer.estimateQuadrant(
        signals: signals,
        noise: noise,
      );

      expect(estimate.index, -1);
      expect(estimate.isConfident, isFalse);
    });

    test('ignora link instavel aprendido na calibracao', () {
      final signals = List<double?>.filled(10, 0)..[6] = 5;
      final noise = List<double>.filled(10, 2)..[6] = 8;

      final estimate = analyzer.estimateQuadrant(
        signals: signals,
        noise: noise,
      );

      expect(estimate.index, -1);
    });
  });
}
