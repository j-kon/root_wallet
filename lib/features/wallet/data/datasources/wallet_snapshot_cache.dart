import 'dart:convert';

import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletSnapshotCache {
  WalletSnapshotCache(
    this._prefs, {
    this.walletId,
    bool Function()? isDecoyActive,
  }) : _isDecoyActive = isDecoyActive ?? (() => false);

  final SharedPreferences _prefs;
  final String? walletId;
  final bool Function() _isDecoyActive;

  String get _cacheKey {
    if (_isDecoyActive()) {
      return 'wallet.snapshot.decoy.v3';
    }
    final id = walletId ?? 'default';
    return 'wallet.snapshot.$id.v3';
  }

  List<String> get _legacyCacheKeys => _isDecoyActive()
      ? const ['wallet.snapshot.decoy.v2', 'wallet.snapshot.decoy.v1']
      : const ['wallet.snapshot.v2', 'wallet.snapshot.v1'];

  Future<void> clear() async {
    await _prefs.remove(_cacheKey);
    if (walletId == 'w_primary_migrated' || walletId == null) {
      for (final legacyKey in _legacyCacheKeys) {
        await _prefs.remove(legacyKey);
      }
    }
  }

  Future<WalletSnapshot?> read() async {
    String? raw = _prefs.getString(_cacheKey);
    if ((raw == null || raw.isEmpty) &&
        (walletId == 'w_primary_migrated' || walletId == null)) {
      for (final legacyKey in _legacyCacheKeys) {
        final val = _prefs.getString(legacyKey);
        if (val != null && val.isNotEmpty) {
          raw = val;
          break;
        }
      }
    }
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
    if (walletId == 'w_primary_migrated' || walletId == null) {
      for (final legacyKey in _legacyCacheKeys) {
        await _prefs.remove(legacyKey);
      }
    }
  }
}
