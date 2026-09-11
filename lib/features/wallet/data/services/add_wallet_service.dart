import 'dart:io';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/descriptor_validator.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddWalletException implements Exception {
  const AddWalletException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'AddWalletException: $message${cause != null ? " ($cause)" : ""}';
}

class AddWalletDuplicateException extends AddWalletException {
  const AddWalletDuplicateException(super.message, [super.cause]);
}

/// Service executing "Add Wallet" flows (create, restore, import watch-only)
/// with strict isolation, transactionality, and zero interference with existing wallets or decoy storage.
class AddWalletService {
  AddWalletService({
    required SecureStorage secureStorage,
    required SharedPreferences preferences,
    required Future<String> Function() walletStoragePathLoader,
    WalletRegistry? registry,
  })  : _secureStorage = secureStorage,
        _preferences = preferences,
        _walletStoragePathLoader = walletStoragePathLoader,
        _registry = registry;

  final SecureStorage _secureStorage;
  final SharedPreferences _preferences;
  final Future<String> Function() _walletStoragePathLoader;
  final WalletRegistry? _registry;

  WalletRegistry get _registryInstance => _registry ?? WalletRegistry(_preferences);

  static const _networkKind = bdk.NetworkKind.test;
  static const _networkName = 'testnet';

  /// Creates a brand new signing wallet with an isolated namespace.
  ///
  /// Guarantees:
  /// - Generates a new unique [WalletRecord.generateId()].
  /// - Writes only to wallet-scoped secure storage keys (`wallet.<id>.*`).
  /// - Never touches global legacy keys or decoy mnemonic.
  /// - Creates isolated database directory `wallets/<id>/` (fails closed if creation fails).
  /// - Rolls back newly created wallet data on any failure before completion.
  /// - Preserves all existing wallets, databases, and labels.
  Future<WalletCreationResult> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletName,
  }) async {
    final phrase = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();
    final id = WalletRecord.generateId();

    // Derive BIP32 master fingerprint
    final parsed = bdk.Mnemonic.fromString(mnemonic: phrase);
    final secKey = bdk.DescriptorSecretKey(
      networkKind: _networkKind,
      mnemonic: parsed,
      password: null,
    );
    final pubKey = secKey.asPublic();
    final fingerprint = pubKey.masterFingerprint().toUpperCase();
    secKey.dispose();
    pubKey.dispose();
    parsed.dispose();

    try {
      // 1. Scoped storage writes
      await _secureStorage.write(
        key: WalletStorageKeys.mnemonicFor(id),
        value: phrase,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.scriptTypeFor(id),
        value: scriptType.storageValue,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.capabilityFor(id),
        value: WalletCapability.signing.storageValue,
      );
      await _secureStorage.delete(
        key: WalletStorageKeys.externalDescriptorFor(id),
      );
      await _secureStorage.delete(
        key: WalletStorageKeys.internalDescriptorFor(id),
      );

      // 2. Verify scoped storage write
      final readBack = await _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(id),
      );
      if (readBack != phrase) {
        throw const AddWalletException(
          'Secure storage verification failed: written mnemonic mismatch.',
        );
      }

      // 3. Create isolated directory (fail closed)
      await _createIsolatedDir(id);

      // 4. Register record in registry
      final registry = _registryInstance;
      final defaultName = 'Wallet ${registry.getWallets().length + 1}';
      final record = WalletRecord(
        id: id,
        name: walletName ?? defaultName,
        type: WalletType.signing,
        scriptType: scriptType,
        network: _networkName,
        createdAt: DateTime.now(),
        fingerprint: fingerprint,
        isActive: false,
      );

      await registry.registerWallet(record, makeActive: false);

      final identity = WalletIdentity(
        id: id,
        fingerprint: fingerprint,
        network: _networkName,
        capability: WalletCapability.signing,
      );

      return WalletCreationResult(
        walletIdentity: identity,
        recoveryPhrase: phrase,
        walletRecord: record,
      );
    } catch (e) {
      await _rollbackPartialWallet(id);
      if (e is AddWalletException) rethrow;
      throw AddWalletException('Failed to create wallet "$id": $e', e);
    }
  }

  /// Restores an existing wallet from recovery phrase into an isolated namespace.
  ///
  /// Guarantees:
  /// - Validates recovery phrase checksum.
  /// - Derives BIP32 master fingerprint.
  /// - Prevents duplicate signing wallets with the same master fingerprint and script type.
  /// - Writes only to wallet-scoped secure storage keys (`wallet.<id>.*`).
  /// - Never touches global legacy keys or decoy credentials.
  /// - Creates isolated database directory `wallets/<id>/` (fails closed if creation fails).
  /// - Rolls back newly created wallet data on any failure before completion.
  Future<WalletRecord> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletName,
  }) async {
    final normalized = _normalizeMnemonic(mnemonic);
    _validateMnemonicShape(normalized);

    final bdk.Mnemonic parsed;
    try {
      parsed = bdk.Mnemonic.fromString(mnemonic: normalized);
    } catch (_) {
      throw const FormatException('Invalid recovery phrase checksum.');
    }

    final secKey = bdk.DescriptorSecretKey(
      networkKind: _networkKind,
      mnemonic: parsed,
      password: null,
    );
    final pubKey = secKey.asPublic();
    final fingerprint = pubKey.masterFingerprint().toUpperCase();
    secKey.dispose();
    pubKey.dispose();
    parsed.dispose();

    // Duplicate detection: check if same signing wallet + script type already exists
    final registry = _registryInstance;
    final existingWallets = registry.getWallets();
    for (final w in existingWallets) {
      if (w.isSigning &&
          w.fingerprint != null &&
          w.fingerprint!.toUpperCase() == fingerprint &&
          w.scriptType == scriptType) {
        throw AddWalletDuplicateException(
          'A wallet with this master key and ${scriptType.displayName} addresses already exists ("${w.name}").',
        );
      }
    }

    final id = WalletRecord.generateId();

    try {
      // 1. Scoped storage writes
      await _secureStorage.write(
        key: WalletStorageKeys.mnemonicFor(id),
        value: normalized,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.scriptTypeFor(id),
        value: scriptType.storageValue,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.capabilityFor(id),
        value: WalletCapability.signing.storageValue,
      );
      await _secureStorage.delete(
        key: WalletStorageKeys.externalDescriptorFor(id),
      );
      await _secureStorage.delete(
        key: WalletStorageKeys.internalDescriptorFor(id),
      );

      // 2. Verify scoped storage write
      final readBack = await _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(id),
      );
      if (readBack != normalized) {
        throw const AddWalletException(
          'Secure storage verification failed: written mnemonic mismatch.',
        );
      }

      // 3. Create isolated directory (fail closed)
      await _createIsolatedDir(id);

      // 4. Register record in registry
      final defaultName = 'Restored Wallet ${existingWallets.length + 1}';
      final record = WalletRecord(
        id: id,
        name: walletName ?? defaultName,
        type: WalletType.signing,
        scriptType: scriptType,
        network: _networkName,
        createdAt: DateTime.now(),
        fingerprint: fingerprint,
        isActive: false,
      );

      await registry.registerWallet(record, makeActive: false);
      return record;
    } catch (e) {
      await _rollbackPartialWallet(id);
      if (e is AddWalletException) rethrow;
      throw AddWalletException('Failed to restore wallet "$id": $e', e);
    }
  }

  /// Imports a watch-only wallet from public descriptor / tpub into an isolated namespace.
  ///
  /// Guarantees:
  /// - Validates descriptor syntax.
  /// - Prevents duplicate watch-only wallets with identical external descriptor.
  /// - Writes only to wallet-scoped secure storage keys (`wallet.<id>.*`).
  /// - NEVER deletes or touches decoy mnemonic or signing mnemonics.
  /// - Creates isolated database directory `wallets/<id>/` (fails closed if creation fails).
  /// - Rolls back newly created wallet data on any failure before completion.
  Future<WalletRecord> importWatchOnlyWallet({
    required String externalDescriptor,
    String? internalDescriptor,
    String? walletName,
  }) async {
    final validated = DescriptorValidator.validate(
      externalInput: externalDescriptor,
      internalInput: internalDescriptor,
    );

    // Duplicate detection: check if identical external descriptor is already imported
    final registry = _registryInstance;
    final existingWallets = registry.getWallets();
    for (final w in existingWallets) {
      if (w.isWatchOnly) {
        final existingExt = await _secureStorage.read(
          key: WalletStorageKeys.externalDescriptorFor(w.id),
        );
        if (existingExt != null &&
            existingExt.trim() == validated.externalDescriptor.trim()) {
          throw AddWalletDuplicateException(
            'A watch-only wallet with this descriptor is already imported ("${w.name}").',
          );
        }
      }
    }

    final id = WalletRecord.generateId();

    try {
      // 1. Scoped storage writes
      await _secureStorage.write(
        key: WalletStorageKeys.capabilityFor(id),
        value: WalletCapability.watchOnly.storageValue,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.externalDescriptorFor(id),
        value: validated.externalDescriptor,
      );
      if (validated.internalDescriptor != null &&
          validated.internalDescriptor!.isNotEmpty) {
        await _secureStorage.write(
          key: WalletStorageKeys.internalDescriptorFor(id),
          value: validated.internalDescriptor!,
        );
      } else {
        await _secureStorage.delete(
          key: WalletStorageKeys.internalDescriptorFor(id),
        );
      }
      await _secureStorage.write(
        key: WalletStorageKeys.scriptTypeFor(id),
        value: validated.scriptType.storageValue,
      );
      await _secureStorage.delete(key: WalletStorageKeys.mnemonicFor(id));

      // 2. Verify scoped storage write
      final readBack = await _secureStorage.read(
        key: WalletStorageKeys.externalDescriptorFor(id),
      );
      if (readBack != validated.externalDescriptor) {
        throw const AddWalletException(
          'Secure storage verification failed: written descriptor mismatch.',
        );
      }

      // 3. Create isolated directory (fail closed)
      await _createIsolatedDir(id);

      // 4. Register record in registry
      final defaultName = 'Watch-Only ${existingWallets.length + 1}';
      final record = WalletRecord(
        id: id,
        name: walletName ?? defaultName,
        type: WalletType.watchOnly,
        scriptType: validated.scriptType,
        network: _networkName,
        createdAt: DateTime.now(),
        fingerprint: validated.fingerprint,
        isActive: false,
      );

      await registry.registerWallet(record, makeActive: false);
      return record;
    } catch (e) {
      await _rollbackPartialWallet(id);
      if (e is AddWalletException) rethrow;
      throw AddWalletException('Failed to import watch-only wallet "$id": $e', e);
    }
  }

  Future<void> _createIsolatedDir(String walletId) async {
    try {
      final basePath = await _walletStoragePathLoader();
      final isolatedDir = Directory('$basePath/wallets/$walletId');
      if (await isolatedDir.exists()) {
        await isolatedDir.delete(recursive: true);
      }
      await isolatedDir.create(recursive: true);
    } catch (e) {
      throw AddWalletException(
        'Failed to create isolated storage directory for wallet "$walletId": $e',
        e,
      );
    }
  }

  Future<void> _rollbackPartialWallet(String walletId) async {
    // 1. Delete scoped secure storage keys
    for (final key in WalletStorageKeys.allKeysFor(walletId)) {
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {}
    }

    // 2. Delete isolated directory if created
    try {
      final basePath = await _walletStoragePathLoader();
      final dir = Directory('$basePath/wallets/$walletId');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}

    // 3. Remove from registry if registered
    try {
      final registry = _registryInstance;
      if (registry.getWallets().any((w) => w.id == walletId)) {
        await registry.deleteWallet(walletId);
      }
    } catch (_) {}
  }

  String _normalizeMnemonic(String mnemonic) {
    return mnemonic
        .toLowerCase()
        .replaceAll(RegExp(r'\b\d{1,2}[\.\):]\s*'), ' ')
        .replaceAll(RegExp('[^a-z]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  void _validateMnemonicShape(String normalized) {
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length != 12 && words.length != 18 && words.length != 24) {
      throw FormatException(
        'Invalid recovery phrase word count: ${words.length}. '
        'Enter 12, 18, or 24 words.',
      );
    }
  }
}
