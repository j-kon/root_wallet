enum TxDirection { incoming, outgoing }

class TxDto {
  const TxDto({
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.direction,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final TxDirection direction;
}
