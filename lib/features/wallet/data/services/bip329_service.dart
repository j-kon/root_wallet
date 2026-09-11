import 'dart:convert';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';

class Bip329ImportResult {
  const Bip329ImportResult({
    required this.snapshot,
    required this.importedCount,
    required this.skippedCount,
  });

  final WalletLabelsSnapshot snapshot;
  final int importedCount;
  final int skippedCount;
}

/// BIP-329 Labels parser and serializer.
///
/// Root Wallet policy:
/// - Enforces UTF-8 byte length limits (2 MB) and max line counts (10,000).
/// - Validates field types strictly before casting; malformed lines never crash import.
/// - Normalizes label and note lengths (label: max 80, note: max 280).
/// - Validates that `addr` records conform to valid Bitcoin Testnet address syntax.
///   Valid testnet addresses from external/historical wallets are preserved even if not
///   derived by the current wallet instance.
/// - Rejects malformed txids and outpoints.
/// - Safely ignores unsupported record types (e.g., `pubkey`, `input`, `xpub`).
class Bip329Service {
  const Bip329Service();

  static const int maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB
  static const int maxLineCount = 10000;
  static const int maxLabelLength = 80;
  static const int maxNoteLength = 280;

  static final RegExp _txidRegex = RegExp(r'^[0-9a-fA-F]{64}$');
  static final RegExp _outpointRegex = RegExp(r'^[0-9a-fA-F]{64}:[0-9]+$');

  /// Exports current [WalletLabelsSnapshot] into BIP-329 JSONL format.
  String exportJsonl(WalletLabelsSnapshot snapshot) {
    final buffer = StringBuffer();

    // Export addresses
    for (final entry in snapshot.addressLabels.entries) {
      final addr = entry.key.trim();
      final label = entry.value.trim();
      if (addr.isNotEmpty && label.isNotEmpty) {
        buffer.writeln(
          jsonEncode(<String, Object?>{
            'type': 'addr',
            'ref': addr,
            'label': label,
          }),
        );
      }
    }

    // Export transactions
    for (final entry in snapshot.transactionMetadata.entries) {
      final txId = entry.key.trim();
      final meta = entry.value;
      if (txId.isNotEmpty && !meta.isEmpty) {
        final map = <String, Object?>{
          'type': 'tx',
          'ref': txId,
          if (meta.label.trim().isNotEmpty) 'label': meta.label.trim(),
          if (meta.note.trim().isNotEmpty) 'note': meta.note.trim(),
        };
        buffer.writeln(jsonEncode(map));
      }
    }

    // Export outputs
    for (final entry in snapshot.outputLabels.entries) {
      final outpoint = entry.key.trim();
      final label = entry.value.trim();
      if (outpoint.isNotEmpty && label.isNotEmpty) {
        buffer.writeln(
          jsonEncode(<String, Object?>{
            'type': 'output',
            'ref': outpoint,
            'label': label,
          }),
        );
      }
    }

    return buffer.toString();
  }

  /// Parses BIP-329 JSONL string and merges into [existingSnapshot] (or fresh if null).
  Bip329ImportResult parseJsonl(
    String jsonlContent, {
    WalletLabelsSnapshot? existingSnapshot,
  }) {
    // Check actual UTF-8 byte length
    final byteLength = utf8.encode(jsonlContent).length;
    if (byteLength > maxFileSizeBytes) {
      throw ArgumentError('BIP-329 content exceeds maximum size of 2 MB.');
    }

    final lines = const LineSplitter().convert(jsonlContent);
    if (lines.length > maxLineCount) {
      throw ArgumentError('BIP-329 content exceeds maximum of 10,000 records.');
    }

    final base = existingSnapshot ?? const WalletLabelsSnapshot();
    final addressMap = Map<String, String>.from(base.addressLabels);
    final txMap = Map<String, WalletTransactionMetadata>.from(
      base.transactionMetadata,
    );
    final outputMap = Map<String, String>.from(base.outputLabels);

    var importedCount = 0;
    var skippedCount = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      Map<String, Object?> record;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          skippedCount++;
          continue;
        }
        record = decoded.cast<String, Object?>();
      } catch (_) {
        skippedCount++;
        continue;
      }

      // Strictly validate field types BEFORE casting
      final rawType = record['type'];
      final rawRef = record['ref'];
      final rawLabel = record['label'];
      final rawNote = record['note'];

      if (rawType is! String || rawRef is! String) {
        skippedCount++;
        continue;
      }

      if (rawLabel != null && rawLabel is! String) {
        skippedCount++;
        continue;
      }

      if (rawNote != null && rawNote is! String) {
        skippedCount++;
        continue;
      }

      final cleanRef = rawRef.trim();
      final cleanLabel = _normalize(rawLabel as String?, maxLength: maxLabelLength);
      final cleanNote = _normalize(rawNote as String?, maxLength: maxNoteLength);

      switch (rawType.trim().toLowerCase()) {
        case 'addr':
          // Validate Bitcoin Testnet address syntax
          try {
            bdk.Address(address: cleanRef, network: bdk.Network.testnet);
          } catch (_) {
            skippedCount++;
            continue;
          }
          if (cleanLabel.isNotEmpty) {
            addressMap[cleanRef] = cleanLabel;
            importedCount++;
          } else {
            skippedCount++;
          }
          break;

        case 'tx':
          if (!_txidRegex.hasMatch(cleanRef)) {
            skippedCount++;
            continue;
          }
          if (cleanLabel.isNotEmpty || cleanNote.isNotEmpty) {
            final existing = txMap[cleanRef];
            txMap[cleanRef] = WalletTransactionMetadata(
              label: cleanLabel.isNotEmpty
                  ? cleanLabel
                  : (existing?.label ?? ''),
              note: cleanNote.isNotEmpty ? cleanNote : (existing?.note ?? ''),
            );
            importedCount++;
          } else {
            skippedCount++;
          }
          break;

        case 'output':
          if (!_outpointRegex.hasMatch(cleanRef)) {
            skippedCount++;
            continue;
          }
          if (cleanLabel.isNotEmpty) {
            outputMap[cleanRef] = cleanLabel;
            importedCount++;
          } else {
            skippedCount++;
          }
          break;

        default:
          // Safely skip unknown or unsupported record types (e.g. pubkey, xpub, input)
          skippedCount++;
          break;
      }
    }

    final updatedSnapshot = WalletLabelsSnapshot(
      addressLabels: addressMap,
      transactionMetadata: txMap,
      outputLabels: outputMap,
    );

    return Bip329ImportResult(
      snapshot: updatedSnapshot,
      importedCount: importedCount,
      skippedCount: skippedCount,
    );
  }

  static String _normalize(String? value, {required int maxLength}) {
    if (value == null) return '';
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= maxLength) {
      return compact;
    }
    return compact.substring(0, maxLength).trimRight();
  }
}
