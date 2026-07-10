class EndpointNormalizer {
  const EndpointNormalizer();

  String normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
      return trimmed;
    }
    return 'ws://$trimmed';
  }
}
