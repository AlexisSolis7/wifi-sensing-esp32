class LinkReading {
  const LinkReading({required this.from, required this.to, required this.rssi});

  final String from;
  final String to;
  final int? rssi;

  double get quality {
    final value = rssi;
    if (value == null) return 0;
    return ((value.clamp(-90, -20) + 90) / 70).clamp(0, 1).toDouble();
  }
}
