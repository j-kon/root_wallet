import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WalletTransactionMetadata {
  const WalletTransactionMetadata({this.label = '', this.note = ''});

  factory WalletTransactionMetadata.fromJson(Map<String, Object?> json) {
    return WalletTransactionMetadata(
      label: json['label'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  final String label;
  final String note;

  bool get isEmpty => label.trim().isEmpty && note.trim().isEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{'label': label, 'note': note};
  }
}

class WalletLabelsSnapshot {
  const WalletLabelsSnapshot({
    this.addressLabels = const <String, String>{},
    this.transactionMetadata = const <String, WalletTransactionMetadata>{},
    this.outputLabels = const <String, String>{},
  });

  factory WalletLabelsSnapshot.fromJson(Map<String, Object?> json) {
    final addresses = json['addresses'];
    final transactions = json['transactions'];
    final outputs = json['outputs'];

    return WalletLabelsSnapshot(
      addressLabels: addresses is Map
          ? addresses.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      transactionMetadata: transactions is Map
          ? transactions.map((key, value) {
              final metadata = value is Map
                  ? WalletTransactionMetadata.fromJson(
                      value.cast<String, Object?>(),
                    )
                  : const WalletTransactionMetadata();
              return MapEntry(key.toString(), metadata);
            })
          : const <String, WalletTransactionMetadata>{},
      outputLabels: outputs is Map
          ? outputs.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }

  final Map<String, String> addressLabels;
  final Map<String, WalletTransactionMetadata> transactionMetadata;
  final Map<String, String> outputLabels;

  String addressLabel(String address) => addressLabels[address] ?? '';

  String outputLabel(String outpoint) => outputLabels[outpoint] ?? '';

  WalletTransactionMetadata transactionMeta(String txId) {
    return transactionMetadata[txId] ?? const WalletTransactionMetadata();
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'addresses': addressLabels,
      'transactions': transactionMetadata.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'outputs': outputLabels,
    };
  }

  WalletLabelsSnapshot copyWith({
    Map<String, String>? addressLabels,
    Map<String, WalletTransactionMetadata>? transactionMetadata,
    Map<String, String>? outputLabels,
  }) {
    return WalletLabelsSnapshot(
      addressLabels: addressLabels ?? this.addressLabels,
      transactionMetadata: transactionMetadata ?? this.transactionMetadata,
      outputLabels: outputLabels ?? this.outputLabels,
    );
  }
}

class WalletLabelStore {
  WalletLabelStore(this._prefs, {String scope = defaultScope})
      : scope = _sanitizeScope(scope);

  static const defaultScope = 'primary';
  static const legacyKey = 'wallet.local_labels.v1';
  static const _baseKeyPrefix = 'wallet.local_labels.v2.';

  final SharedPreferences _prefs;
  final String scope;

  String get storageKey => '$_baseKeyPrefix$scope';

  static String _sanitizeScope(String raw) {
    final cleaned = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return cleaned.isEmpty ? defaultScope : cleaned;
  }

  WalletLabelsSnapshot read() {
    _performMigrationIfNeeded();

    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const WalletLabelsSnapshot();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const WalletLabelsSnapshot();
    }

    return WalletLabelsSnapshot.fromJson(decoded.cast<String, Object?>());
  }

  /// Migrates legacy v1 labels into v2.primary deterministically.
  ///
  /// Strictly prevents leaking legacy labels into decoy or watch-only wallets.
  void _performMigrationIfNeeded() {
    if (scope == defaultScope) {
      final existingV2 = _prefs.getString(storageKey);
      if (existingV2 == null || existingV2.trim().isEmpty) {
        final legacyRaw = _prefs.getString(legacyKey);
        if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
          _prefs.setString(storageKey, legacyRaw);
        }
      }
    }
  }

  Future<void> write(WalletLabelsSnapshot snapshot) {
    return _prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> setAddressLabel(String address, String label) async {
    final snapshot = read();
    final nextAddresses = Map<String, String>.from(snapshot.addressLabels);
    final normalized = _normalize(label, maxLength: 80);
    if (normalized.isEmpty) {
      nextAddresses.remove(address);
    } else {
      nextAddresses[address] = normalized;
    }
    await write(snapshot.copyWith(addressLabels: nextAddresses));
  }

  Future<void> setTransactionMetadata({
    required String txId,
    required String label,
    required String note,
  }) async {
    final snapshot = read();
    final nextTransactions = Map<String, WalletTransactionMetadata>.from(
      snapshot.transactionMetadata,
    );
    final metadata = WalletTransactionMetadata(
      label: _normalize(label, maxLength: 80),
      note: _normalize(note, maxLength: 280),
    );
    if (metadata.isEmpty) {
      nextTransactions.remove(txId);
    } else {
      nextTransactions[txId] = metadata;
    }
    await write(snapshot.copyWith(transactionMetadata: nextTransactions));
  }

  Future<void> setOutputLabel(String outpoint, String label) async {
    final snapshot = read();
    final nextOutputs = Map<String, String>.from(snapshot.outputLabels);
    final normalized = _normalize(label, maxLength: 80);
    if (normalized.isEmpty) {
      nextOutputs.remove(outpoint);
    } else {
      nextOutputs[outpoint] = normalized;
    }
    await write(snapshot.copyWith(outputLabels: nextOutputs));
  }

  Future<void> clear() async {
    await _prefs.remove(storageKey);
    if (scope == defaultScope) {
      await _prefs.remove(legacyKey);
    }
  }

  String _normalize(String value, {required int maxLength}) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= maxLength) {
      return compact;
    }
    return compact.substring(0, maxLength).trimRight();
  }
}
