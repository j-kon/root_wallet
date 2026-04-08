import 'dart:convert';

import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletSnapshotCache {
  WalletSnapshotCache(this._prefs);

  static const _cacheKey = 'wallet.snapshot.v2';
  static const _legacyCacheKey = 'wallet.snapshot.v1';
  final SharedPreferences _prefs;

  Future<void> clear() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_legacyCacheKey);
  }

  Future<WalletSnapshot?> read() async {
    final raw =
        _prefs.getString(_cacheKey) ?? _prefs.getString(_legacyCacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = WalletSnapshot.fromJson(decoded);
      if (snapshot.schemaVersion != AppConstants.walletSnapshotSchemaVersion) {
        await clear();
        return null;
      }
      return snapshot;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> write(WalletSnapshot snapshot) async {
    final encoded = jsonEncode(snapshot.toJson());
    await _prefs.setString(_cacheKey, encoded);
    await _prefs.remove(_legacyCacheKey);
  }
}
