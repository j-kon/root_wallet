class WalletSnapshotTx {
  const WalletSnapshotTx({
    required this.txId,
    required this.amountSats,
    required this.timestampMs,
    required this.isIncoming,
    required this.status,
    this.feeSats,
    this.confirmations,
  });

  factory WalletSnapshotTx.fromJson(Map<String, dynamic> json) {
    return WalletSnapshotTx(
      txId: json['txId'] as String,
      amountSats: json['amountSats'] as int,
      timestampMs: json['timestampMs'] as int,
      isIncoming: json['isIncoming'] as bool,
      status: json['status'] as String,
      feeSats: json['feeSats'] as int?,
      confirmations: json['confirmations'] as int?,
    );
  }

  final String txId;
  final int amountSats;
  final int timestampMs;
  final bool isIncoming;
  final String status;
  final int? feeSats;
  final int? confirmations;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'txId': txId,
      'amountSats': amountSats,
      'timestampMs': timestampMs,
      'isIncoming': isIncoming,
      'status': status,
      'feeSats': feeSats,
      'confirmations': confirmations,
    };
  }
}

class WalletSnapshot {
  const WalletSnapshot({
    required this.confirmedSats,
    required this.pendingSats,
    required this.receiveAddress,
    required this.lastSyncedAtMs,
    required this.transactions,
  });

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTxs = (json['transactions'] as List<dynamic>? ?? <dynamic>[]);
    return WalletSnapshot(
      confirmedSats: json['confirmedSats'] as int,
      pendingSats: json['pendingSats'] as int,
      receiveAddress: json['receiveAddress'] as String,
      lastSyncedAtMs: json['lastSyncedAtMs'] as int,
      transactions: rawTxs
          .map((tx) => WalletSnapshotTx.fromJson(tx as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int confirmedSats;
  final int pendingSats;
  final String receiveAddress;
  final int lastSyncedAtMs;
  final List<WalletSnapshotTx> transactions;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'confirmedSats': confirmedSats,
      'pendingSats': pendingSats,
      'receiveAddress': receiveAddress,
      'lastSyncedAtMs': lastSyncedAtMs,
      'transactions': transactions.map((tx) => tx.toJson()).toList(),
    };
  }
}
