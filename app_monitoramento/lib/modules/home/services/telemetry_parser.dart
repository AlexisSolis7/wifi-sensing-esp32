import '../domain/telemetry_message.dart';

class TelemetryParser {
  const TelemetryParser();

  TelemetryMessage parse(String message) {
    if (message == 'MOVIMENTO_DETECTADO') {
      return const MovementTelemetryMessage();
    }

    if (message.startsWith('ALERTA:ZONA_')) {
      return ZoneAlertTelemetryMessage(
        message.replaceFirst('ALERTA:ZONA_', '').trim(),
      );
    }

    if (message.startsWith('MATRIX:')) {
      return _parseMatrix(message);
    }

    return UnknownTelemetryMessage(message);
  }

  TelemetryMessage _parseMatrix(String message) {
    final payload = message.replaceFirst('MATRIX:', '');
    final parts = payload.split(',');
    if (parts.length != 25) {
      return InvalidTelemetryMessage(
        'Matriz invalida: ${parts.length} valores recebidos',
      );
    }

    return MatrixTelemetryMessage(
      parts.map((part) => int.tryParse(part.trim())).toList(),
    );
  }
}
