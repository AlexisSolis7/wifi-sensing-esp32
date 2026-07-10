import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'domain/link_reading.dart';
import 'domain/mesh_connection_status.dart';
import 'domain/mesh_constants.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF20212A),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(controller: controller),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusStrip(controller: controller),
                        const SizedBox(height: 18),
                        _ConnectionPanel(controller: controller),
                        const SizedBox(height: 18),
                        _CalibrationPanel(controller: controller),
                        const SizedBox(height: 18),
                        _DecisionPanel(controller: controller),
                        const SizedBox(height: 18),
                        _DashboardGrid(controller: controller),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF23242E),
        border: Border(bottom: BorderSide(color: Color(0xFF454756))),
      ),
      child: Row(
        children: [
          const Text(
            'wifi_sensing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(left: 4, top: 22),
            color: Color(0xFF7EA2FF),
          ),
          const Spacer(),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Image.asset(
                'assets/images/ufsc_logo_dark.png',
                height: 42,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final map = _Panel(
          title: 'Mapa de quadrantes',
          child: Obx(
            () => AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _MeshMapPainter(
                  matrix: controller.matrix.toList(),
                  links: controller.links,
                  activeQuadrantIndex: controller.activeQuadrantIndex,
                  calibrated: controller.hasBaseline,
                  movement: controller.shouldHighlightQuadrant,
                ),
              ),
            ),
          ),
        );
        final details = Column(
          children: [
            _LinksPanel(controller: controller),
            const SizedBox(height: 18),
            _MatrixPanel(controller: controller),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: map),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: details),
            ],
          );
        }

        return Column(children: [map, const SizedBox(height: 18), details]);
      },
    );
  }
}

class _DecisionPanel extends StatelessWidget {
  const _DecisionPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final confidence = controller.quadrantConfidence.value;
      final status = controller.detectionLabel;
      final statusColor =
          controller.shouldHighlightQuadrant || controller.regionUncertain.value
          ? const Color(0xFFFF6B7A)
          : const Color(0xFFB9BBC8);

      return _Panel(
        title: 'Decisao de regiao',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'confianca ${confidence.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFB9BBC8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'O app usa os links mais alterados, descarta links instaveis da calibracao e so fixa um quadrante quando ha margem contra o segundo colocado.',
              style: TextStyle(color: Color(0xFFB9BBC8)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < MeshConstants.quadrantLabels.length; i++)
                  _ScoreChip(
                    label: MeshConstants.quadrantLabels[i],
                    score: controller.quadrantScores[i],
                    active: controller.activeQuadrantIndex == i,
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.label,
    required this.score,
    required this.active,
  });

  final String label;
  final double score;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF3A2630) : const Color(0xFF1F2029),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? const Color(0xFFFF6B7A) : const Color(0xFF4B4D5D),
        ),
      ),
      child: Text(
        '$label: ${score.toStringAsFixed(1)}',
        style: TextStyle(
          color: active ? const Color(0xFFFF9AA5) : const Color(0xFFE7E9F5),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CalibrationPanel extends StatelessWidget {
  const _CalibrationPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final progress = controller.calibrationProgress.value;
      final isCalibrating = controller.isCalibrating.value;
      final hasBaseline = controller.hasBaseline;

      return _Panel(
        title: 'Calibracao do ambiente vazio',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: isCalibrating
                      ? null
                      : controller.calibrarAmbienteVazio,
                  icon: const Icon(Icons.tune),
                  label: const Text('Calibrar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: isCalibrating ? progress : (hasBaseline ? 1 : 0),
              minHeight: 8,
              color: hasBaseline || isCalibrating
                  ? const Color(0xFF7EA2FF)
                  : const Color(0xFF9CA3AF),
              backgroundColor: const Color(0xFF4B4D5D),
            ),
            const SizedBox(height: 10),
            Text(
              isCalibrating
                  ? 'Capturando baseline por cerca de 15 segundos... ${(progress * 100).round()}%'
                  : hasBaseline
                  ? 'Baseline pronta. Maior variacao: ${controller.strongestDelta.toStringAsFixed(1)} dB. Sinal util: ${controller.strongestSignal.toStringAsFixed(1)} dB. Estado: ${controller.detectionLabel}.'
                  : 'Deixe a mesa vazia e clique em Calibrar antes dos testes.',
              style: const TextStyle(color: Color(0xFFB9BBC8)),
            ),
          ],
        ),
      );
    });
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final connected =
          controller.connectionStatus.value == MeshConnectionStatus.connected;

      return _Panel(
        title: 'Gateway WebSocket',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              runSpacing: 12,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: controller.endpointController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lan_outlined),
                      labelText: 'Endpoint',
                      hintText: 'ws://192.168.4.1:81',
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: controller.conectarWebSocket,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => controller.conectarWebSocket(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Conectar'),
                ),
                OutlinedButton.icon(
                  onPressed: connected ? controller.desconectar : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Desconectar'),
                ),
              ],
            ),
            if (controller.errorMessage.value.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                controller.errorMessage.value,
                style: const TextStyle(
                  color: Color(0xFFFF6B7A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeZone = controller.activeZone.value;
      final alarmText = controller.shouldHighlightQuadrant
          ? 'Movimento em ${controller.activeQuadrantLabel}'
          : controller.hasMovement
          ? 'Movimento detectado'
          : controller.statusAlarme.value
          ? activeZone.isEmpty
                ? 'Movimento detectado'
                : 'Movimento na zona $activeZone'
          : 'Sem alerta ativo';

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricTile(
            icon: Icons.wifi_tethering,
            label: 'Conexao',
            value: controller.connectionLabel,
            color: _connectionColor(controller.connectionStatus.value),
          ),
          _MetricTile(
            icon: Icons.grid_on,
            label: 'Matrizes',
            value: controller.matrixCount.value.toString(),
            color: const Color(0xFF7EA2FF),
          ),
          _MetricTile(
            icon: Icons.sensors,
            label: 'Leituras validas',
            value: controller.validReadingCount.toString(),
            color: const Color(0xFF43A86B),
          ),
          _MetricTile(
            icon: Icons.warning_amber,
            label: 'Alerta',
            value: alarmText,
            color:
                controller.statusAlarme.value ||
                    controller.hasMovement ||
                    controller.shouldHighlightQuadrant
                ? const Color(0xFFFF6B7A)
                : const Color(0xFFB9BBC8),
          ),
          _MetricTile(
            icon: Icons.dashboard_customize,
            label: 'Quadrante',
            value: controller.detectionLabel,
            color:
                controller.shouldHighlightQuadrant ||
                    controller.regionUncertain.value
                ? const Color(0xFFFF6B7A)
                : const Color(0xFFB9BBC8),
          ),
        ],
      );
    });
  }

  Color _connectionColor(MeshConnectionStatus status) {
    switch (status) {
      case MeshConnectionStatus.connected:
        return const Color(0xFF43A86B);
      case MeshConnectionStatus.connecting:
        return const Color(0xFFF5B84B);
      case MeshConnectionStatus.error:
        return const Color(0xFFFF6B7A);
      case MeshConnectionStatus.disconnected:
        return const Color(0xFFB9BBC8);
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: _Panel(
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFB9BBC8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinksPanel extends StatelessWidget {
  const _LinksPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final links = controller.links;
      final deltas = controller.linkDeltas;
      final signals = controller.linkSignals;

      return _Panel(
        title: 'Links RSSI da malha',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < links.length; i++) ...[
              _LinkRow(link: links[i], delta: deltas[i], signal: signals[i]),
              if (i != links.length - 1) const Divider(height: 18),
            ],
          ],
        ),
      );
    });
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.delta,
    required this.signal,
  });

  final LinkReading link;
  final double? delta;
  final double? signal;

  @override
  Widget build(BuildContext context) {
    final color = _rssiColor(link.rssi);
    final value = link.rssi == null ? '--' : '${link.rssi} dBm';
    final deltaLabel = delta == null
        ? ''
        : '  var ${delta!.toStringAsFixed(1)}';
    final signalLabel = signal == null
        ? ''
        : '  sig ${signal!.toStringAsFixed(1)}';

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            '${link.from}-${link.to}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: link.quality,
              color: color,
              backgroundColor: const Color(0xFF4B4D5D),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: Text(
            '$value$deltaLabel$signalLabel',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _MatrixPanel extends StatelessWidget {
  const _MatrixPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: 'Matriz bruta A/E/U/Y/M',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const _MatrixCell(text: ''),
                    for (final label in MeshConstants.nodeNames)
                      _MatrixCell(text: label, header: true),
                  ],
                ),
                for (var row = 0; row < MeshConstants.nodeNames.length; row++)
                  TableRow(
                    children: [
                      _MatrixCell(
                        text: MeshConstants.nodeNames[row],
                        header: true,
                      ),
                      for (
                        var col = 0;
                        col < MeshConstants.nodeNames.length;
                        col++
                      )
                        _MatrixCell(
                          text: _formatRssi(controller.matrix[row * 5 + col]),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              controller.lastMessage.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB9BBC8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({required this.text, this.header = false});

  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: header ? const Color(0xFF30364A) : const Color(0xFF1F2029),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF353748)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF23242E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF4B4D5D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF4B4D5D)),
          ],
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _MeshMapPainter extends CustomPainter {
  const _MeshMapPainter({
    required this.matrix,
    required this.links,
    required this.activeQuadrantIndex,
    required this.calibrated,
    required this.movement,
  });

  static const nodeZones = {'A': 0, 'E': 4, 'U': 20, 'Y': 24, 'M': 12};
  static const quadrantNames = [
    'Superior\nesquerdo',
    'Superior\ndireito',
    'Inferior\nesquerdo',
    'Inferior\ndireito',
  ];

  final List<int?> matrix;
  final List<LinkReading> links;
  final int activeQuadrantIndex;
  final bool calibrated;
  final bool movement;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final cell = side / 5;

    _drawQuadrants(canvas, origin, side);
    _drawLinks(canvas, origin, cell);
    _drawNodes(canvas, origin, cell);
  }

  void _drawQuadrants(Canvas canvas, Offset origin, double side) {
    final center = origin + Offset(side / 2, side / 2);
    final rects = [
      Rect.fromLTRB(origin.dx, origin.dy, center.dx, center.dy),
      Rect.fromLTRB(center.dx, origin.dy, origin.dx + side, center.dy),
      Rect.fromLTRB(origin.dx, center.dy, center.dx, origin.dy + side),
      Rect.fromLTRB(center.dx, center.dy, origin.dx + side, origin.dy + side),
    ];
    final labelPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < rects.length; i++) {
      final isActive = calibrated && movement && activeQuadrantIndex == i;
      final rect = rects[i].deflate(5);
      final fill = Paint()
        ..color = isActive ? const Color(0xFF5A2630) : const Color(0xFF214431);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 3 : 1.5
        ..color = isActive ? const Color(0xFFFF6B7A) : const Color(0xFF43A86B);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        border,
      );

      labelPainter.text = TextSpan(
        text: quadrantNames[i],
        style: TextStyle(
          color: isActive ? const Color(0xFFFFC1C8) : const Color(0xFFBDEFD0),
          fontWeight: FontWeight.w900,
          fontSize: side * 0.045,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, rect.topLeft + Offset(12, 10));
    }

    final guidePaint = Paint()
      ..color = const Color(0xFFE7E9F5).withValues(alpha: 0.18)
      ..strokeWidth = math.max(2, side * 0.004)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, origin.dy),
      Offset(center.dx, origin.dy + side),
      guidePaint,
    );
    canvas.drawLine(
      Offset(origin.dx, center.dy),
      Offset(origin.dx + side, center.dy),
      guidePaint,
    );
  }

  void _drawLinks(Canvas canvas, Offset origin, double cell) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final link in links) {
      final startIndex = nodeZones[link.from];
      final endIndex = nodeZones[link.to];
      if (startIndex == null || endIndex == null || link.rssi == null) continue;

      final start = _zoneCenter(origin, cell, startIndex);
      final end = _zoneCenter(origin, cell, endIndex);
      final paint = Paint()
        ..color = _rssiColor(link.rssi).withValues(alpha: 0.78)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2 + link.quality * 5;
      canvas.drawLine(start, end, paint);

      final midpoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      textPainter.text = TextSpan(
        text: '${link.rssi} dBm',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      final labelRect = Rect.fromCenter(
        center: midpoint,
        width: textPainter.width + 10,
        height: textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFF20212A).withValues(alpha: 0.86),
      );
      textPainter.paint(canvas, labelRect.topLeft + const Offset(5, 3));
    }
  }

  void _drawNodes(Canvas canvas, Offset origin, double cell) {
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    for (final entry in nodeZones.entries) {
      final center = _zoneCenter(origin, cell, entry.value);
      final radius = cell * 0.16;
      canvas.drawCircle(center, radius + 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFF7EA2FF),
      );

      textPainter.text = TextSpan(
        text: entry.key,
        style: TextStyle(
          color: Colors.white,
          fontSize: cell * 0.18,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  Offset _zoneCenter(Offset origin, double cell, int index) {
    final col = index % 5;
    final row = index ~/ 5;
    return Offset(
      origin.dx + col * cell + cell / 2,
      origin.dy + row * cell + cell / 2,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshMapPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.activeQuadrantIndex != activeQuadrantIndex ||
        oldDelegate.calibrated != calibrated ||
        oldDelegate.movement != movement ||
        oldDelegate.links != links;
  }
}

String _formatRssi(int? value) {
  if (value == null || value == 0 || value < -100 || value > -1) return '--';
  return value.toString();
}

Color _rssiColor(int? value) {
  if (value == null) return const Color(0xFF686B7C);
  final quality = ((value.clamp(-90, -20) + 90) / 70).clamp(0, 1).toDouble();
  if (quality > 0.66) return const Color(0xFF7EA2FF);
  if (quality > 0.34) return const Color(0xFFF5B84B);
  return const Color(0xFFFF6B7A);
}
