import 'dart:convert';
import 'dart:typed_data';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
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

  /// Maximum allowed decoded PSBT binary size (500 KB limit).
  static const int maxPsbtSizeBytes = 500 * 1024;

  /// Centralized validation and parsing path for all incoming PSBT strings.
  ///
  /// Enforces:
  /// - Trim and whitespace normalization
  /// - Strict Base64 decoding
  /// - Binary payload size limit (<= 500 KB decoded bytes)
  /// - BIP-174 magic bytes check ("psbt\xff" / 0x70 0x73 0x62 0x74 0xff)
  /// - BDK Psbt instantiation
  (bdk.Psbt psbt, Uint8List rawBytes, String cleanedBase64) _parseValidatedPsbt(
    String rawInput,
  ) {
    final cleaned = _cleanPsbtString(rawInput);
    if (cleaned.isEmpty) {
      throw const FormatException('PSBT input cannot be empty.');
    }

    final Uint8List rawBytes;
    try {
      rawBytes = Uint8List.fromList(base64.decode(cleaned));
    } catch (e) {
      throw FormatException('Malformed Base64 PSBT payload: $e');
    }

    if (rawBytes.length > maxPsbtSizeBytes) {
      throw ArgumentError(
        'Decoded PSBT binary size (${rawBytes.length} bytes) exceeds '
        'maximum allowed limit of $maxPsbtSizeBytes bytes (500 KB).',
      );
    }

    // Verify BIP-174 magic bytes: "psbt\xff"
    if (rawBytes.length < 5 ||
        rawBytes[0] != 0x70 ||
        rawBytes[1] != 0x73 ||
        rawBytes[2] != 0x62 ||
        rawBytes[3] != 0x74 ||
        rawBytes[4] != 0xff) {
      throw const FormatException(
        'Invalid PSBT magic header. Expected "psbt\\xff".',
      );
    }

    final bdk.Psbt psbt;
    try {
      psbt = bdk.Psbt(psbtBase64: cleaned);
    } catch (e) {
      throw FormatException('Invalid PSBT format: $e');
    }

    return (psbt, rawBytes, cleaned);
  }

  /// Parses and inspects a PSBT Base64 string against the active wallet.
  Future<PsbtDetails> inspectPsbt(String rawInput) async {
    final (psbt, rawBytes, psbtBase64) = _parseValidatedPsbt(rawInput);

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
        // Authoritative change classification:
        // ONLY mark CHANGE when proven from wallet keychain derivation metadata
        if (i < psbtOutputs.length && psbtOutputs[i] is Map) {
          final psbtOut = psbtOutputs[i] as Map<String, dynamic>;
          final bip32 = psbtOut['bip32_derivation'];
          final tapOrigins = psbtOut['tap_key_origins'];
          if ((bip32 != null && bip32.toString().contains('/1/')) ||
              (tapOrigins != null && tapOrigins.toString().contains('/1/'))) {
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
    if (!hasOwnedInput && inputs.isNotEmpty) {
      hasUnownedInputs = true;
    }

    final realTxid = _deriveRealTxid(psbt, rawBytes);

    return PsbtDetails(
      rawPsbtBase64: psbtBase64,
      txid: realTxid,
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
      final lockedKey = _walletService.isDecoyActive
          ? 'settings.decoy_locked_utxos'
          : (_walletService.walletId != null
              ? 'wallet.${_walletService.walletId}.locked_utxos'
              : 'settings.locked_utxos');
      final lockedList = prefs.getStringList(lockedKey) ??
          prefs.getStringList('settings.locked_utxos') ??
          [];
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
  ///
  /// Throws [StateError] if:
  /// - The wallet is watch-only
  /// - None of the inputs belong to the active wallet
  Future<PsbtSigningResult> signPsbt(String rawInput) async {
    final capability = await _walletService.getCapability();
    if (!capability.canSignTransactions) {
      throw StateError('Watch-only wallets cannot sign transactions.');
    }

    final (psbt, _, _) = _parseValidatedPsbt(rawInput);
    final wallet = await _walletService.resolveWallet();

    // Verify at least one input belongs to active wallet before signing
    final jsonStr = psbt.jsonSerialize();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final psbtInputs = (data['inputs'] as List?) ?? [];

    var hasOwnedInput = false;
    for (final inp in psbtInputs) {
      if (inp is Map<String, dynamic>) {
        final witnessUtxo = inp['witness_utxo'] as Map<String, dynamic>?;
        if (witnessUtxo != null) {
          final scriptHex = witnessUtxo['script_pubkey']?.toString();
          if (scriptHex != null && scriptHex.isNotEmpty) {
            try {
              final script = _scriptFromHex(scriptHex);
              if (wallet.isMine(script: script)) {
                hasOwnedInput = true;
                break;
              }
            } catch (_) {}
          }
        }
      }
    }

    if (!hasOwnedInput && psbtInputs.isNotEmpty) {
      throw StateError(
        'Cannot sign PSBT: None of the transaction inputs belong to this wallet.',
      );
    }

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
  ///
  /// Rejects unfinalized PSBTs fail-closed.
  Future<String> broadcastPsbt(String rawInput) async {
    final (psbt, _, _) = _parseValidatedPsbt(rawInput);
    if (!_checkFinalized(psbt)) {
      throw StateError(
        'Cannot broadcast unfinalized PSBT. Transaction must be fully signed and finalized.',
      );
    }
    final tx = psbt.extractTx();
    return _walletService.broadcastTransaction(tx);
  }

  /// Verifies whether all inputs in [psbt] are genuinely finalized.
  bool _checkFinalized(bdk.Psbt psbt) {
    try {
      final jsonStr = psbt.jsonSerialize();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final inputs = (data['inputs'] as List?) ?? [];
      if (inputs.isEmpty) {
        return false;
      }

      for (final inp in inputs) {
        if (inp is! Map<String, dynamic>) return false;
        final hasScriptSig = inp['final_script_sig'] != null;
        final hasWitness = inp['final_script_witness'] != null;
        if (!hasScriptSig && !hasWitness) {
          return false;
        }
      }

      psbt.extractTx();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Derives the real Bitcoin unsigned transaction txid from the PSBT global map,
  /// or from the finalized transaction if available. Never fabricates a hash.
  String? _deriveRealTxid(bdk.Psbt psbt, Uint8List rawBytes) {
    // 1. Try deriving from consensus unsigned transaction in PSBT global map
    try {
      final unsignedTxBytes = _extractUnsignedTxBytesFromPsbt(rawBytes);
      if (unsignedTxBytes != null && unsignedTxBytes.isNotEmpty) {
        final tx = bdk.Transaction(transactionBytes: unsignedTxBytes);
        return tx.computeTxid().toString();
      }
    } catch (_) {}

    // 2. Try extracting from finalized transaction
    try {
      final tx = psbt.extractTx();
      return tx.computeTxid().toString();
    } catch (_) {}

    return null;
  }

  /// Extracts the BIP-174 consensus unsigned transaction bytes from the global map.
  static Uint8List? _extractUnsignedTxBytesFromPsbt(Uint8List psbtBytes) {
    if (psbtBytes.length < 5 ||
        psbtBytes[0] != 0x70 ||
        psbtBytes[1] != 0x73 ||
        psbtBytes[2] != 0x62 ||
        psbtBytes[3] != 0x74 ||
        psbtBytes[4] != 0xff) {
      return null;
    }

    var offset = 5;
    while (offset < psbtBytes.length) {
      final (keyLen, keyLenBytes) = _readVarInt(psbtBytes, offset);
      offset += keyLenBytes;
      if (keyLen == 0) {
        break; // End of global map
      }

      if (offset + keyLen > psbtBytes.length) break;
      final keyBytes = psbtBytes.sublist(offset, offset + keyLen);
      offset += keyLen;

      final (valLen, valLenBytes) = _readVarInt(psbtBytes, offset);
      offset += valLenBytes;

      if (offset + valLen > psbtBytes.length) break;
      final valBytes = psbtBytes.sublist(offset, offset + valLen);
      offset += valLen;

      // PSBT_GLOBAL_UNSIGNED_TX = 0x00 with 1-byte key length
      if (keyLen == 1 && keyBytes[0] == 0x00) {
        return valBytes;
      }
    }

    return null;
  }

  static (int, int) _readVarInt(Uint8List bytes, int offset) {
    if (offset >= bytes.length) return (0, 0);
    final first = bytes[offset];
    if (first < 0xfd) {
      return (first, 1);
    } else if (first == 0xfd) {
      if (offset + 2 >= bytes.length) return (0, 0);
      final val = bytes[offset + 1] | (bytes[offset + 2] << 8);
      return (val, 3);
    } else if (first == 0xfe) {
      if (offset + 4 >= bytes.length) return (0, 0);
      final val = bytes[offset + 1] |
          (bytes[offset + 2] << 8) |
          (bytes[offset + 3] << 16) |
          (bytes[offset + 4] << 24);
      return (val, 5);
    } else {
      if (offset + 8 >= bytes.length) return (0, 0);
      var val = 0;
      for (var i = 0; i < 8; i++) {
        val |= (bytes[offset + 1 + i] << (8 * i));
      }
      return (val, 9);
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
