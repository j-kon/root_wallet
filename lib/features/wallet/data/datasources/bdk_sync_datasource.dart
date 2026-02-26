import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:root_wallet/features/wallet/data/dtos/tx_dto.dart';

class BdkSyncDatasource {
  BdkSyncDatasource({required BdkWalletDatasource walletDatasource})
    : _walletDatasource = walletDatasource;

  final BdkWalletDatasource _walletDatasource;

  Future<void> sync() {
    return _walletDatasource.syncWallet();
  }

  Future<int> confirmedBalance() async {
    final wallet = await _walletDatasource.resolveWallet();
    return _toInt(wallet.getBalance().confirmed);
  }

  Future<int> pendingBalance() async {
    final wallet = await _walletDatasource.resolveWallet();
    final balance = wallet.getBalance();
    return _toInt(balance.trustedPending + balance.untrustedPending);
  }

  Future<List<TxDto>> transactions() async {
    final wallet = await _walletDatasource.resolveWallet();
    final blockchain = await _walletDatasource.resolveBlockchain();
    final chainHeight = await blockchain.getHeight();
    final txs = wallet.listTransactions(includeRaw: true);

    final mapped = txs
        .map((tx) => _toTxDto(tx, chainHeight: chainHeight))
        .toList(growable: false);
    mapped.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return mapped;
  }

  TxDto _toTxDto(TransactionDetails tx, {required int chainHeight}) {
    final receivedSats = _toInt(tx.received);
    final sentSats = _toInt(tx.sent);
    final isIncoming = receivedSats >= sentSats;
    final amount = (isIncoming ? receivedSats - sentSats : sentSats - receivedSats)
        .abs();

    final blockTime = tx.confirmationTime;
    final timestamp = blockTime == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(
            _toInt(blockTime.timestamp) * 1000,
          );
    final confirmations = blockTime == null
        ? 0
        : _safeConfirmations(chainHeight: chainHeight, blockHeight: blockTime.height);

    return TxDto(
      txId: tx.txid,
      amountSats: amount,
      timestamp: timestamp,
      direction: isIncoming ? TxDirection.incoming : TxDirection.outgoing,
      status: blockTime == null ? TxStatus.pending : TxStatus.confirmed,
      feeSats: tx.fee == null ? null : _toInt(tx.fee!),
      confirmations: confirmations,
    );
  }

  int _safeConfirmations({
    required int chainHeight,
    required int blockHeight,
  }) {
    final depth = chainHeight - blockHeight + 1;
    return depth <= 0 ? 1 : depth;
  }

  int _toInt(BigInt value) {
    return value.toInt();
  }
}
