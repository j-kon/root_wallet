import 'dart:io';

import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletStorageCleanupException implements Exception {
  const WalletStorageCleanupException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'WalletStorageCleanupException: $message${cause != null ? " ($cause)" : ""}';
}

/// Standalone service for permanently cleaning up isolated per-wallet storage data.
///
/// Designed to execute destructively via an idempotent multi-step cleanup without
/// depending on the lifecycle of active [BdkWalletService] or Riverpod providers.
class WalletStorageCleaner {
  const WalletStorageCleaner({
    required SecureStorage secureStorage,
    required SharedPreferences preferences,
    required Future<String> Function() walletStoragePathLoader,
  })  : _secureStorage = secureStorage,
        _preferences = preferences,
        _walletStoragePathLoader = walletStoragePathLoader;

  final SecureStorage _secureStorage;
  final SharedPreferences _preferences;
  final Future<String> Function() _walletStoragePathLoader;

  /// Deletes all data, databases, labels, and secrets associated with [walletId].
  ///
  /// Guarantees:
  /// - Leaves all other wallet keys and databases completely untouched.
  /// - Decoy storage is preserved.
  /// - Idempotent multi-step cleanup: can be safely retried if interrupted.
  /// - Throws [WalletStorageCleanupException] if any stage of cleanup fails.
  Future<void> deleteWalletData(String walletId) async {
    final failures = <String>[];

    // 1. Delete all wallet-scoped keys from SecureStorage
    for (final key in WalletStorageKeys.allKeysFor(walletId)) {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        failures.add('SecureStorage key "$key": $e');
      }
    }

    // 2. Remove wallet-scoped labels, locked UTXOs, and snapshot cache
    for (final prefKey in [
      'wallet.local_labels.v3.$walletId',
      'wallet.$walletId.locked_utxos',
      'wallet.snapshot.$walletId.v3',
    ]) {
      try {
        await _preferences.remove(prefKey);
      } catch (e) {
        failures.add('SharedPreferences key "$prefKey": $e');
      }
    }

    // 3. Purge isolated SQLite directory
    try {
      final basePath = await _walletStoragePathLoader();
      final isolatedDir = Directory('$basePath/wallets/$walletId');
      if (await isolatedDir.exists()) {
        await isolatedDir.delete(recursive: true);
      }
    } catch (e) {
      failures.add('Isolated directory for "$walletId": $e');
    }

    if (failures.isNotEmpty) {
      throw WalletStorageCleanupException(
        'Failed to clean up wallet data for "$walletId":\n- ${failures.join("\n- ")}',
      );
    }
  }

  /// Alias for [deleteWalletData].
  Future<void> cleanWalletData(String walletId) => deleteWalletData(walletId);
}
