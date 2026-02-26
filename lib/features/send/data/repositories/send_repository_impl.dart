import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:root_wallet/features/send/data/datasources/broadcast_datasource.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';

class SendRepositoryImpl implements SendRepository {
  SendRepositoryImpl({
    required BroadcastDatasource broadcastDatasource,
    required BdkWalletDatasource walletDatasource,
  }) : _broadcastDatasource = broadcastDatasource,
       _walletDatasource = walletDatasource;

  final BroadcastDatasource _broadcastDatasource;
  final BdkWalletDatasource _walletDatasource;
  final Map<String, PartiallySignedTransaction> _psbtCache =
      <String, PartiallySignedTransaction>{};
  final Map<String, Transaction> _signedTxCache = <String, Transaction>{};

  @override
  Future<String> broadcastTx(String signedTx) {
    return _broadcast(signedTx);
  }

  @override
  Future<String> buildTx(SendRequest request) async {
    final wallet = await _walletDatasource.resolveWallet();
    final network = wallet.network();
    final address = await Address.fromString(s: request.address, network: network);
    final script = address.scriptPubkey();

    final txBuilder = TxBuilder()
      ..enableRbf()
      ..feeRate(request.feeRate.satsPerVByte.toDouble())
      ..addRecipient(script, BigInt.from(request.amountSats));

    final (psbt, _) = await txBuilder.finish(wallet);
    final serialized = psbt.toString();
    _psbtCache[serialized] = psbt;
    return serialized;
  }

  @override
  Future<String> signTx(String psbt) async {
    final wallet = await _walletDatasource.resolveWallet();
    final parsed = _psbtCache.remove(psbt) ??
        await PartiallySignedTransaction.fromString(psbt);

    final isFinalized = wallet.sign(psbt: parsed);
    if (!isFinalized) {
      throw StateError('Transaction could not be finalized.');
    }

    final transaction = parsed.extractTx();
    final serialized = transaction.toString();
    _signedTxCache[serialized] = transaction;
    return serialized;
  }

  Future<String> _broadcast(String signedTx) async {
    final cached = _signedTxCache.remove(signedTx);
    if (cached != null) {
      return _broadcastDatasource.broadcast(cached);
    }

    final transactionBytes = _hexToBytes(signedTx);
    final transaction = await Transaction.fromBytes(
      transactionBytes: transactionBytes,
    );
    return _broadcastDatasource.broadcast(transaction);
  }

  List<int> _hexToBytes(String hex) {
    final normalized = hex.trim();
    if (normalized.isEmpty || normalized.length.isOdd) {
      throw const FormatException('Invalid transaction payload.');
    }

    final bytes = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      final segment = normalized.substring(i, i + 2);
      final value = int.tryParse(segment, radix: 16);
      if (value == null) {
        throw const FormatException('Invalid transaction payload.');
      }
      bytes.add(value);
    }
    return bytes;
  }
}
