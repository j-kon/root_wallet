import 'dart:convert';
import 'dart:typed_data';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:root_wallet/features/psbt/domain/entities/psbt_details.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PsbtSigningResult {
  const PsbtSigningResult({
    required this.signedPsbtBase64,
    required this.isFinalized,
    this.rawTransactionHex,
  });

  final String signedPsbtBase64;
  final bool isFinalized;
  final String? rawTransactionHex;
}

class PsbtService {
  const PsbtService({
    required BdkWalletService walletService,
  }) : _walletService = walletService;

  final BdkWalletService _walletService;

  static const int maxPsbtSizeBytes = 500 * 1024; // 500 KB limit

  /// Parses and inspects a PSBT Base64 string against the active wallet.
  Future<PsbtDetails> inspectPsbt(String rawInput) async {
    final psbtBase64 = _cleanPsbtString(rawInput);
    if (psbtBase64.length > maxPsbtSizeBytes) {
      throw ArgumentError('PSBT exceeds maximum allowed size of 500 KB.');
    }

    final bdk.Psbt psbt;
    try {
      psbt = bdk.Psbt(psbtBase64: psbtBase64);
    } catch (e) {
      throw FormatException('Invalid PSBT format: $e');
    }

    final wallet = await _walletService.resolveWallet();
    final network = wallet.network();
    final capability = await _walletService.getCapability();

    final jsonStr = psbt.jsonSerialize();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final unsignedTx = data['unsigned_tx'] as Map<String, dynamic>?;
    final rawInputs = (unsignedTx?['input'] as List?) ?? [];
    final rawOutputs = (unsignedTx?['output'] as List?) ?? [];
    final psbtInputs = (data['inputs'] as List?) ?? [];
    final psbtOutputs = (data['outputs'] as List?) ?? [];

    final inputs = <PsbtInputItem>[];
    int? totalInputSats = 0;
    var allInputsHaveAmount = true;
    var hasOwnedInput = false;

    for (var i = 0; i < rawInputs.length; i++) {
      final item = rawInputs[i] as Map<String, dynamic>;
      final prevOut = item['previous_output']?.toString() ?? '';
      final parts = prevOut.split(':');
      final txid = parts.isNotEmpty ? parts[0] : '';
      final vout = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final sequence = (item['sequence'] as num?)?.toInt();

      int? amount;
      var isMine = false;

      if (i < psbtInputs.length && psbtInputs[i] is Map) {
        final psbtIn = psbtInputs[i] as Map<String, dynamic>;
        final witnessUtxo = psbtIn['witness_utxo'] as Map<String, dynamic>?;
        if (witnessUtxo != null) {
          amount = (witnessUtxo['value'] as num?)?.toInt();
          final scriptHex = witnessUtxo['script_pubkey']?.toString();
          if (scriptHex != null && scriptHex.isNotEmpty) {
            try {
              final script = _scriptFromHex(scriptHex);
              isMine = wallet.isMine(script: script);
            } catch (_) {}
          }
        }
      }

      if (isMine) {
        hasOwnedInput = true;
      }

      if (amount != null && totalInputSats != null) {
        totalInputSats += amount;
      } else {
        allInputsHaveAmount = false;
        totalInputSats = null;
      }

      inputs.add(
        PsbtInputItem(
          outpoint: prevOut,
          txid: txid,
          vout: vout,
          amountSats: amount,
          isMine: isMine,
          sequence: sequence,
        ),
      );
    }

    final outputs = <PsbtOutputItem>[];
    var totalOutputSats = 0;

    for (var i = 0; i < rawOutputs.length; i++) {
      final item = rawOutputs[i] as Map<String, dynamic>;
      final amount = (item['value'] as num?)?.toInt() ?? 0;
      final scriptHex = item['script_pubkey']?.toString() ?? '';
      totalOutputSats += amount;

      String? address;
      var isMine = false;
      var isChange = false;

      if (scriptHex.isNotEmpty) {
        try {
          final script = _scriptFromHex(scriptHex);
          isMine = wallet.isMine(script: script);
          address = _addressFromScript(script, network);
        } catch (_) {}
      }

      if (isMine) {
        if (i < psbtOutputs.length && psbtOutputs[i] is Map) {
          final psbtOut = psbtOutputs[i] as Map<String, dynamic>;
          final bip32 = psbtOut['bip32_derivation'];
          if (bip32 != null && bip32.toString().contains('/1/')) {
            isChange = true;
          }
        }
        // If not explicitly marked via bip32, but isMine and there's another non-mine output
        if (!isChange && rawOutputs.length > 1) {
          final hasOtherNonMine = rawOutputs.asMap().entries.any((entry) {
            if (entry.key == i) return false;
            final otherHex = (entry.value as Map)['script_pubkey']?.toString() ?? '';
            try {
              return !wallet.isMine(script: _scriptFromHex(otherHex));
            } catch (_) {
              return true;
            }
          });
          if (hasOtherNonMine) {
            isChange = true;
          }
        }
      }

      outputs.add(
        PsbtOutputItem(
          amountSats: amount,
          scriptPubkeyHex: scriptHex,
          address: address,
          isMine: isMine,
          isChange: isChange,
        ),
      );
    }

    int? feeSats;
    try {
      feeSats = psbt.fee();
    } catch (_) {
      if (allInputsHaveAmount && totalInputSats != null) {
        feeSats = totalInputSats - totalOutputSats;
      }
    }

    var hasUnownedInputs = inputs.any((input) => !input.isMine);
    // If inputs had no witness_utxo script, we couldn't determine ownership directly,
    // so don't flag as unowned unless we know for sure or have none owned
    if (!hasOwnedInput && inputs.isNotEmpty) {
      hasUnownedInputs = true;
    }

    String txid = '';
    try {
      final tx = psbt.extractTx();
      txid = tx.computeTxid().toString();
    } catch (_) {
      final rawTx = data['unsigned_tx'];
      if (rawTx != null) {
        txid = sha256.convert(utf8.encode(jsonEncode(rawTx))).toString();
      }
    }

    return PsbtDetails(
      rawPsbtBase64: psbtBase64,
      txid: txid,
      inputs: inputs,
      outputs: outputs,
      totalOutputSats: totalOutputSats,
      totalInputSats: totalInputSats,
      feeSats: feeSats,
      isFinalized: _checkFinalized(psbt),
      hasUnownedInputs: hasUnownedInputs,
      canSign: capability.canSignTransactions,
      network: network.name,
    );
  }

  /// Constructs an unsigned PSBT from a [SendRequest] using the active wallet.
  Future<String> createPsbt(SendRequest request) async {
    final wallet = await _walletService.resolveWallet();
    final network = wallet.network();
    final address = bdk.Address(address: request.address, network: network);
    final script = address.scriptPubkey();

    var txBuilder = bdk.TxBuilder()
        .feeRate(
          feeRate: bdk.FeeRate.fromSatPerVb(
            satVb: request.feeRate.satsPerVByte,
          ),
        )
        .addRecipient(
          script: script,
          amount: bdk.Amount.fromSat(satoshi: request.amountSats),
        )
        .nlocktime(locktime: bdk.BlocksLockTime(0));

    if (request.selectedUtxos != null && request.selectedUtxos!.isNotEmpty) {
      final selectedOutpoints = request.selectedUtxos!.map((outpointStr) {
        final parts = outpointStr.split(':');
        final txid = parts[0];
        final vout = int.parse(parts[1]);
        return bdk.OutPoint(
          txid: bdk.Txid.fromString(hex: txid),
          vout: vout,
        );
      }).toList();
      txBuilder = txBuilder
          .addUtxos(outpoints: selectedOutpoints)
          .manuallySelectedOnly();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final lockedList = prefs.getStringList('settings.locked_utxos') ?? [];
      for (final lockedStr in lockedList) {
        final parts = lockedStr.split(':');
        if (parts.length == 2) {
          final txid = parts[0];
          final vout = int.tryParse(parts[1]);
          if (vout != null) {
            final outpoint = bdk.OutPoint(
              txid: bdk.Txid.fromString(hex: txid),
              vout: vout,
            );
            txBuilder = txBuilder.addUnspendable(unspendable: outpoint);
          }
        }
      }
    }

    final psbt = txBuilder.finish(wallet: wallet);
    return psbt.serialize();
  }

  /// Signs an inspected PSBT with the active wallet.
  /// Throws [StateError] if the wallet is watch-only or has no signing inputs.
  Future<PsbtSigningResult> signPsbt(String rawInput) async {
    final capability = await _walletService.getCapability();
    if (!capability.canSignTransactions) {
      throw StateError('Watch-only wallets cannot sign transactions.');
    }

    final psbtBase64 = _cleanPsbtString(rawInput);
    final psbt = bdk.Psbt(psbtBase64: psbtBase64);
    final wallet = await _walletService.resolveWallet();

    final isFinalized = wallet.sign(psbt: psbt, signOptions: null);

    String? rawTxHex;
    if (isFinalized) {
      try {
        final tx = psbt.extractTx();
        rawTxHex = _bytesToHex(tx.serialize());
      } catch (_) {}
    }

    return PsbtSigningResult(
      signedPsbtBase64: psbt.serialize(),
      isFinalized: isFinalized,
      rawTransactionHex: rawTxHex,
    );
  }

  /// Broadcasts a finalized PSBT to the Bitcoin network.
  Future<String> broadcastPsbt(String rawInput) async {
    final psbtBase64 = _cleanPsbtString(rawInput);
    final psbt = bdk.Psbt(psbtBase64: psbtBase64);
    final tx = psbt.extractTx();
    return _walletService.broadcastTransaction(tx);
  }

  bool _checkFinalized(bdk.Psbt psbt) {
    try {
      psbt.extractTx();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _cleanPsbtString(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), '');
  }

  bdk.Script _scriptFromHex(String hex) {
    final clean = hex.trim();
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bdk.Script(rawOutputScript: Uint8List.fromList(bytes));
  }

  String? _addressFromScript(bdk.Script script, bdk.Network network) {
    try {
      return bdk.Address.fromScript(script: script, network: network).toString();
    } catch (_) {
      return null;
    }
  }

  String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
