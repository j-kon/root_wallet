class TxItem {
  const TxItem({
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.isIncoming,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final bool isIncoming;
}
