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
  });

  factory WalletLabelsSnapshot.fromJson(Map<String, Object?> json) {
    final addresses = json['addresses'];
    final transactions = json['transactions'];

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
    );
  }

  final Map<String, String> addressLabels;
  final Map<String, WalletTransactionMetadata> transactionMetadata;

  String addressLabel(String address) => addressLabels[address] ?? '';

  WalletTransactionMetadata transactionMeta(String txId) {
    return transactionMetadata[txId] ?? const WalletTransactionMetadata();
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'addresses': addressLabels,
      'transactions': transactionMetadata.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  WalletLabelsSnapshot copyWith({
    Map<String, String>? addressLabels,
    Map<String, WalletTransactionMetadata>? transactionMetadata,
  }) {
    return WalletLabelsSnapshot(
      addressLabels: addressLabels ?? this.addressLabels,
      transactionMetadata: transactionMetadata ?? this.transactionMetadata,
    );
  }
}

class WalletLabelStore {
  WalletLabelStore(this._prefs);

  static const _key = 'wallet.local_labels.v1';
  final SharedPreferences _prefs;

  WalletLabelsSnapshot read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const WalletLabelsSnapshot();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const WalletLabelsSnapshot();
    }

    return WalletLabelsSnapshot.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> write(WalletLabelsSnapshot snapshot) {
    return _prefs.setString(_key, jsonEncode(snapshot.toJson()));
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

  Future<void> clear() {
    return _prefs.remove(_key);
  }

  String _normalize(String value, {required int maxLength}) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= maxLength) {
      return compact;
    }
    return compact.substring(0, maxLength).trimRight();
  }
}
