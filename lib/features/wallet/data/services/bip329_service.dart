import 'dart:convert';

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

class Bip329Service {
  const Bip329Service();

  static const int maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB
  static const int maxLineCount = 10000;

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
  ///
  /// Enforces:
  /// - Max size: 2 MB
  /// - Max lines: 10,000
  /// - Strict type/ref validation for known types (`tx`, `addr`, `output`)
  /// - Unknown types gracefully ignored
  Bip329ImportResult parseJsonl(
    String jsonlContent, {
    WalletLabelsSnapshot? existingSnapshot,
  }) {
    if (jsonlContent.length > maxFileSizeBytes) {
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

      final type = record['type'];
      final ref = record['ref'];
      final label = record['label'] as String? ?? '';
      final note = record['note'] as String? ?? '';

      if (type is! String || ref is! String) {
        skippedCount++;
        continue;
      }

      final cleanRef = ref.trim();
      final cleanLabel = label.trim();
      final cleanNote = note.trim();

      switch (type.trim().toLowerCase()) {
        case 'addr':
          // Testnet address length reasonable check
          if (cleanRef.length < 14 || cleanRef.length > 90) {
            skippedCount++;
            continue;
          }
          if (cleanLabel.isNotEmpty) {
            addressMap[cleanRef] = cleanLabel;
            importedCount++;
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
          }
          break;

        default:
          // Gracefully skip unknown or unsupported record types (e.g. pubkey, xpub, input)
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
}
