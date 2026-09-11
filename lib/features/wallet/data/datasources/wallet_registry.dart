import 'dart:convert';

import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletRegistryException implements Exception {
  const WalletRegistryException(this.message);
  final String message;

  @override
  String toString() => 'WalletRegistryException: $message';
}

/// Persistent registry of non-secret wallet records in Root Wallet.
///
/// Stores metadata and active wallet reference in [SharedPreferences].
/// Sensitive seed material, private keys, and descriptors are stored separately
/// in wallet-scoped secure storage.
class WalletRegistry {
  WalletRegistry(this._prefs);

  final SharedPreferences _prefs;

  static const String registryKey = 'wallet.registry.v1';
  static const String activeWalletIdKey = 'wallet.active_id';

  /// Returns all registered wallets.
  ///
  /// Distinguishes:
  /// - Absent key -> empty valid registry (`[]`)
  /// - Valid JSON list -> parsed records
  /// - Corrupt JSON, non-list, missing ID, or duplicate IDs -> throws [WalletRegistryException]
  List<WalletRecord> getWallets() {
    final raw = _prefs.getString(registryKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <WalletRecord>[];
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw WalletRegistryException('Corrupted registry JSON: $e');
    }

    if (decoded is! List) {
      throw WalletRegistryException(
        'Invalid registry schema: expected JSON List but got ${decoded.runtimeType}',
      );
    }

    final activeId = getActiveWalletId();
    final seenIds = <String>{};
    final records = <WalletRecord>[];

    for (final item in decoded) {
      if (item is! Map) {
        throw const WalletRegistryException(
          'Invalid registry schema: expected JSON Map entry in list.',
        );
      }
      final map = item.cast<String, dynamic>();
      final id = map['id'];
      if (id is! String || id.trim().isEmpty) {
        throw const WalletRegistryException(
          'Invalid registry entry: missing or empty wallet ID.',
        );
      }
      if (!seenIds.add(id)) {
        throw WalletRegistryException(
          'Duplicate wallet ID detected in registry: "$id".',
        );
      }
      try {
        final record = WalletRecord.fromRegistryJson(map);
        records.add(record.copyWith(isActive: record.id == activeId));
      } on FormatException catch (e) {
        throw WalletRegistryException(e.message);
      } catch (e) {
        throw WalletRegistryException('Failed to parse wallet record "$id": $e');
      }
    }

    return List<WalletRecord>.unmodifiable(records);
  }

  /// Returns the ID of the currently active wallet, if any.
  String? getActiveWalletId() {
    return _prefs.getString(activeWalletIdKey);
  }

  /// Sets the active wallet ID.
  Future<void> setActiveWalletId(String walletId) async {
    WalletRecord.validateWalletId(walletId);
    final wallets = getWallets();
    if (!wallets.any((w) => w.id == walletId)) {
      throw WalletRegistryException(
        'Cannot set active wallet: wallet "$walletId" not found in registry.',
      );
    }
    await _prefs.setString(activeWalletIdKey, walletId);
  }

  /// Returns the currently active [WalletRecord], or null if no wallet is active.
  WalletRecord? getActiveWallet() {
    final activeId = getActiveWalletId();
    final wallets = getWallets();
    if (wallets.isEmpty) {
      return null;
    }
    if (activeId == null) {
      return wallets.first.copyWith(isActive: true);
    }
    return wallets.firstWhere(
      (w) => w.id == activeId,
      orElse: () => wallets.first.copyWith(isActive: true),
    );
  }

  /// Returns true if at least one wallet exists in the registry.
  bool hasWallets() {
    return getWallets().isNotEmpty;
  }

  /// Returns a wallet matching the given fingerprint, if any exists.
  WalletRecord? findByFingerprint(String fingerprint) {
    if (fingerprint.trim().isEmpty) return null;
    final normalized = fingerprint.trim().toUpperCase();
    final wallets = getWallets();
    for (final w in wallets) {
      if (w.fingerprint != null && w.fingerprint!.toUpperCase() == normalized) {
        return w;
      }
    }
    return null;
  }

  /// Registers a new wallet.
  ///
  /// If this is the first wallet or [makeActive] is true, sets it as the active wallet.
  Future<void> registerWallet(
    WalletRecord record, {
    bool makeActive = false,
  }) async {
    WalletRecord.validateWalletId(record.id);
    final wallets = getWallets().toList();
    if (wallets.any((w) => w.id == record.id)) {
      throw WalletRegistryException(
        'Wallet with id "${record.id}" already exists in registry.',
      );
    }

    final isFirst = wallets.isEmpty;
    wallets.add(record);
    await _saveWallets(wallets);

    if (isFirst || makeActive) {
      await _prefs.setString(activeWalletIdKey, record.id);
    }
  }

  /// Updates an existing wallet's metadata.
  Future<void> updateWallet(WalletRecord record) async {
    WalletRecord.validateWalletId(record.id);
    final wallets = getWallets().toList();
    final index = wallets.indexWhere((w) => w.id == record.id);
    if (index == -1) {
      throw WalletRegistryException(
        'Cannot update wallet: wallet "${record.id}" not found.',
      );
    }

    wallets[index] = record;
    await _saveWallets(wallets);
  }

  /// Renames a wallet with local display validation.
  Future<void> renameWallet(String walletId, String newName) async {
    WalletRecord.validateWalletId(walletId);
    final validatedName = validateWalletName(newName);
    final wallets = getWallets().toList();
    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index == -1) {
      throw WalletRegistryException(
        'Cannot rename wallet: wallet "$walletId" not found.',
      );
    }

    wallets[index] = wallets[index].copyWith(name: validatedName);
    await _saveWallets(wallets);
  }

  /// Validates a local wallet display name.
  static String validateWalletName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Wallet name cannot be empty.');
    }
    if (trimmed.length > 40) {
      throw const FormatException('Wallet name cannot exceed 40 characters.');
    }
    // Reject control characters (0x00 to 0x1F, 0x7F)
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(trimmed)) {
      throw const FormatException('Wallet name contains invalid characters.');
    }
    return trimmed;
  }

  /// Deletes a wallet from the registry.
  ///
  /// Enforces Last Wallet Protection: throws [StateError] if attempting to delete
  /// the only remaining wallet.
  /// If deleting the active wallet, deterministically selects the first remaining wallet.
  Future<void> deleteWallet(String walletId) async {
    WalletRecord.validateWalletId(walletId);
    final wallets = getWallets().toList();
    if (wallets.length <= 1 && wallets.any((w) => w.id == walletId)) {
      throw StateError(
        'Cannot delete the last remaining wallet. At least one wallet must be maintained.',
      );
    }

    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index == -1) {
      return; // Already deleted
    }

    final activeId = getActiveWalletId();
    final isDeletingActive = activeId == walletId;

    wallets.removeAt(index);
    await _saveWallets(wallets);

    if (isDeletingActive && wallets.isNotEmpty) {
      await _prefs.setString(activeWalletIdKey, wallets.first.id);
    } else if (wallets.isEmpty) {
      await _prefs.remove(activeWalletIdKey);
    }
  }

  /// Clears all registry entries (used during full app reset).
  Future<void> clear() async {
    await _prefs.remove(registryKey);
    await _prefs.remove(activeWalletIdKey);
  }

  Future<void> _saveWallets(List<WalletRecord> wallets) async {
    final encoded = jsonEncode(wallets.map((w) => w.toJson()).toList());
    await _prefs.setString(registryKey, encoded);
  }
}
