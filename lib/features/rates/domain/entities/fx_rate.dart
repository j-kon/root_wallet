class FxRate {
  const FxRate({
    required this.base,
    required this.quote,
    required this.value,
    required this.timestamp,
  });

  final String base;
  final String quote;
  final double value;
  final DateTime timestamp;
}
