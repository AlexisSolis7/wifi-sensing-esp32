sealed class TelemetryMessage {
  const TelemetryMessage();
}

class MatrixTelemetryMessage extends TelemetryMessage {
  const MatrixTelemetryMessage(this.values);

  final List<int?> values;
}

class MovementTelemetryMessage extends TelemetryMessage {
  const MovementTelemetryMessage();
}

class ZoneAlertTelemetryMessage extends TelemetryMessage {
  const ZoneAlertTelemetryMessage(this.zone);

  final String zone;
}

class UnknownTelemetryMessage extends TelemetryMessage {
  const UnknownTelemetryMessage(this.raw);

  final String raw;
}

class InvalidTelemetryMessage extends TelemetryMessage {
  const InvalidTelemetryMessage(this.error);

  final String error;
}
