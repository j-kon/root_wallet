import 'dart:typed_data';

import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:root_wallet/features/send/data/datasources/broadcast_datasource.dart';
import 'package:root_wallet/features/send/domain/entities/send_preview.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';

class SendRepositoryImpl implements SendRepository {
  SendRepositoryImpl({
    required BroadcastDatasource broadcastDatasource,
    required BdkWalletService walletService,
  }) : _broadcastDatasource = broadcastDatasource,
       _walletService = walletService;

  final BroadcastDatasource _broadcastDatasource;
  final BdkWalletService _walletService;
  final Map<String, bdk.Psbt> _psbtCache = <String, bdk.Psbt>{};
  final Map<String, bdk.Transaction> _signedTxCache =
      <String, bdk.Transaction>{};

  @override
  Future<String> broadcastTx(String signedTx) {
    return _broadcast(signedTx);
  }

  @override
  Future<SendPreview> previewTx(SendRequest request) async {
    final psbt = await _buildPsbt(request);
    try {
      final feeSats = psbt.fee();
      return SendPreview(
        estimatedFeeSats: feeSats,
        totalSats: request.amountSats + feeSats,
      );
    } finally {
      psbt.dispose();
    }
  }

  @override
  Future<String> buildTx(SendRequest request) async {
    final psbt = await _buildPsbt(request);
    final serialized = psbt.serialize();
    _psbtCache[serialized] = psbt;
    return serialized;
  }

  Future<bdk.Psbt> _buildPsbt(SendRequest request) async {
    final wallet = await _walletService.resolveWallet();
    final network = wallet.network();
    final address = bdk.Address(address: request.address, network: network);
    final script = address.scriptPubkey();

    final txBuilder = bdk.TxBuilder()
        .feeRate(
          feeRate: bdk.FeeRate.fromSatPerVb(
            satVb: request.feeRate.satsPerVByte,
          ),
        )
        .addRecipient(
          script: script,
          amount: bdk.Amount.fromSat(satoshi: request.amountSats),
        );

    return txBuilder.finish(wallet: wallet);
  }

  @override
  Future<String> signTx(String psbt) async {
    final wallet = await _walletService.resolveWallet();
    final parsed = _psbtCache.remove(psbt) ?? bdk.Psbt(psbtBase64: psbt);

    final isFinalized = wallet.sign(psbt: parsed, signOptions: null);
    if (!isFinalized) {
      throw StateError('Transaction could not be finalized.');
    }

    final transaction = parsed.extractTx();
    final serialized = _bytesToHex(transaction.serialize());
    _signedTxCache[serialized] = transaction;
    return serialized;
  }

  Future<String> _broadcast(String signedTx) async {
    final cached = _signedTxCache.remove(signedTx);
    if (cached != null) {
      return _broadcastDatasource.broadcast(cached);
    }

    final transactionBytes = _hexToBytes(signedTx);
    final transaction = bdk.Transaction(
      transactionBytes: Uint8List.fromList(transactionBytes),
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

  String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
