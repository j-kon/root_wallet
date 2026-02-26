import 'dart:convert';

import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletSnapshotCache {
  WalletSnapshotCache(this._prefs);

  static const _cacheKey = 'wallet.snapshot.v1';
  final SharedPreferences _prefs;

  Future<void> clear() async {
    await _prefs.remove(_cacheKey);
  }

  Future<WalletSnapshot?> read() async {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return WalletSnapshot.fromJson(decoded);
  }

  Future<void> write(WalletSnapshot snapshot) async {
    final encoded = jsonEncode(snapshot.toJson());
    await _prefs.setString(_cacheKey, encoded);
  }
}
