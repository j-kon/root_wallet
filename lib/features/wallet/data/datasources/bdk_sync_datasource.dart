import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/dtos/tx_dto.dart';

class BdkSyncDatasource {
  BdkSyncDatasource({required BdkWalletService walletService})
    : _walletService = walletService;

  final BdkWalletService _walletService;

  Future<void> sync() {
    return _walletService.syncWallet();
  }

  Future<int> confirmedBalance() async {
    final wallet = await _walletService.resolveWallet();
    return wallet.balance().confirmed.toSat();
  }

  Future<int> pendingBalance() async {
    final wallet = await _walletService.resolveWallet();
    final balance = wallet.balance();
    return balance.trustedPending.toSat() + balance.untrustedPending.toSat();
  }

  Future<List<TxDto>> transactions() async {
    final wallet = await _walletService.resolveWallet();
    int? chainHeight;
    try {
      chainHeight = await _walletService.chainHeight();
    } catch (_) {
      chainHeight = null;
    }

    final mapped = wallet
        .transactions()
        .map((canonicalTx) => _toTxDto(wallet, canonicalTx, chainHeight))
        .whereType<TxDto>()
        .toList(growable: false);
    mapped.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return mapped;
  }

  TxDto? _toTxDto(
    bdk.Wallet wallet,
    bdk.CanonicalTx canonicalTx,
    int? chainHeight,
  ) {
    final txid = canonicalTx.transaction.computeTxid();
    final details = wallet.txDetails(txid: txid);
    final values = details == null
        ? wallet.sentAndReceived(tx: canonicalTx.transaction)
        : null;
    final receivedSats = (details?.received ?? values!.received).toSat();
    final sentSats = (details?.sent ?? values!.sent).toSat();
    final isIncoming = receivedSats >= sentSats;
    final amount =
        (isIncoming ? receivedSats - sentSats : sentSats - receivedSats).abs();
    if (amount == 0) {
      return null;
    }

    final chainPosition = details?.chainPosition ?? canonicalTx.chainPosition;
    final timestamp = _timestamp(chainPosition);
    final confirmations = _confirmations(chainPosition, chainHeight);

    return TxDto(
      txId: txid.toString(),
      amountSats: amount,
      timestamp: timestamp,
      direction: isIncoming ? TxDirection.incoming : TxDirection.outgoing,
      status: chainPosition is bdk.ConfirmedChainPosition
          ? TxStatus.confirmed
          : TxStatus.pending,
      feeSats: details?.fee?.toSat(),
      confirmations: confirmations,
    );
  }

  DateTime _timestamp(bdk.ChainPosition chainPosition) {
    if (chainPosition is bdk.ConfirmedChainPosition) {
      return DateTime.fromMillisecondsSinceEpoch(
        chainPosition.confirmationBlockTime.confirmationTime * 1000,
      );
    }
    if (chainPosition is bdk.UnconfirmedChainPosition &&
        chainPosition.timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        chainPosition.timestamp! * 1000,
      );
    }
    return DateTime.now();
  }

  int? _confirmations(bdk.ChainPosition chainPosition, int? chainHeight) {
    if (chainPosition is! bdk.ConfirmedChainPosition) {
      return 0;
    }
    if (chainHeight == null) {
      return null;
    }
    return _safeConfirmations(
      chainHeight: chainHeight,
      blockHeight: chainPosition.confirmationBlockTime.blockId.height,
    );
  }

  int _safeConfirmations({required int chainHeight, required int blockHeight}) {
    final depth = chainHeight - blockHeight + 1;
    return depth <= 0 ? 1 : depth;
  }
}
