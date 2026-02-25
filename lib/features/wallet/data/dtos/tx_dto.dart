enum TxDirection { incoming, outgoing }

enum TxStatus { pending, confirmed }

class TxDto {
  const TxDto({
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.direction,
    required this.status,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final TxDirection direction;
  final TxStatus status;
}
