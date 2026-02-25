enum TxItemStatus { pending, confirmed }

class TxItem {
  const TxItem({
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.isIncoming,
    required this.status,
    this.feeSats,
    this.confirmations,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final bool isIncoming;
  final int? feeSats;
  final int? confirmations;
  final TxItemStatus status;

  bool get isPending => status == TxItemStatus.pending;
}
