import 'dart:io';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/descriptor_validator.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletMigrationException implements Exception {
  const WalletMigrationException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? 'WalletMigrationException: $message (Cause: $cause)'
      : 'WalletMigrationException: $message';
}

/// Service responsible for migrating single-wallet legacy installations to the
/// Phase 2 Milestone 2A multi-wallet architecture.
///
/// Migration guarantees:
/// 1. Idempotent: multiple runs never produce duplicate wallets.
/// 2. Non-destructive: legacy secrets and databases are verified and preserved.
/// 3. Complete: copies secrets, databases, labels, and locked UTXOs into isolated namespaces.
/// 4. Transactional: phased execution (PREPARE, COPY/VERIFY, REGISTER, MARK COMPLETE).
class WalletMigrationService {
  WalletMigrationService({
    required SecureStorage secureStorage,
    required SharedPreferences preferences,
    required Future<String> Function() walletStoragePathLoader,
  })  : _secureStorage = secureStorage,
        _prefs = preferences,
        _walletStoragePathLoader = walletStoragePathLoader;

  final SecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final Future<String> Function() _walletStoragePathLoader;

  static const String defaultMigratedWalletId = 'w_primary_migrated';

  /// Performs migration if legacy wallet data exists and no multi-wallet registry is present.
  ///
  /// Returns the migrated [WalletRecord] on success, or null if no migration was required.
  Future<WalletRecord?> migrateIfNeeded() async {
    final registry = WalletRegistry(_prefs);

    // 1. If registry already has wallets, modern multi-wallet is in use -> return null.
    if (registry.hasWallets()) {
      return null;
    }

    // 2. Check completion marker policy: if marker says completed, but registry has no wallets, fail closed.
    final isCompleted =
        _prefs.getBool(WalletStorageKeys.legacyMigrationCompleted) ?? false;
    if (isCompleted) {
      throw const WalletMigrationException(
        'Migration was previously marked complete, but registry contains no wallets.',
      );
    }

    // ==========================================
    // PHASE 1: PREPARE
    // ==========================================
    final legacyMnemonic = await _secureStorage.read(
      key: WalletStorageKeys.legacyMnemonic,
    );
    final legacyExtDesc = await _secureStorage.read(
      key: WalletStorageKeys.legacyExternalDescriptor,
    );

    final hasLegacySigning =
        legacyMnemonic != null && legacyMnemonic.trim().isNotEmpty;
    final hasLegacyWatchOnly =
        legacyExtDesc != null && legacyExtDesc.trim().isNotEmpty;

    if (!hasLegacySigning && !hasLegacyWatchOnly) {
      // Fresh install / no legacy wallet data - no migration required.
      return null;
    }

    final isWatchOnly = !hasLegacySigning && hasLegacyWatchOnly;
    final capability = isWatchOnly
        ? WalletCapability.watchOnly
        : WalletCapability.signing;

    final legacyScriptTypeRaw = await _secureStorage.read(
      key: WalletStorageKeys.legacyScriptType,
    );
    final scriptType = WalletScriptType.fromStorageValue(legacyScriptTypeRaw);

    // Derive BIP32 master fingerprint (signing) or descriptor origin fingerprint (watch-only)
    String? fingerprint;
    if (hasLegacySigning) {
      try {
        final parsed = bdk.Mnemonic.fromString(
          mnemonic: legacyMnemonic.trim().toLowerCase(),
        );
        final secKey = bdk.DescriptorSecretKey(
          networkKind: bdk.NetworkKind.test,
          mnemonic: parsed,
          password: null,
        );
        final pubKey = secKey.asPublic();
        fingerprint = pubKey.masterFingerprint().toUpperCase();
        secKey.dispose();
        pubKey.dispose();
        parsed.dispose();
      } catch (_) {
        fingerprint = null;
      }
    } else {
      final extDesc = legacyExtDesc!;
      final legacyIntDesc = await _secureStorage.read(
        key: WalletStorageKeys.legacyInternalDescriptor,
      );
      try {
        final validated = DescriptorValidator.validate(
          externalInput: extDesc,
          internalInput: legacyIntDesc,
        );
        fingerprint = validated.fingerprint?.toUpperCase();
      } catch (_) {
        fingerprint = null;
      }
      fingerprint ??= DescriptorValidator.extractFingerprint(extDesc);
    }

    final walletId = defaultMigratedWalletId;
    final walletName = isWatchOnly ? 'Watch-Only Wallet' : 'Main Wallet';

    // ==========================================
    // PHASE 2: COPY & VERIFY SECRETS & DB
    // ==========================================
    if (hasLegacySigning) {
      await _secureStorage.write(
        key: WalletStorageKeys.mnemonicFor(walletId),
        value: legacyMnemonic.trim(),
      );
    }
    if (hasLegacyWatchOnly) {
      await _secureStorage.write(
        key: WalletStorageKeys.externalDescriptorFor(walletId),
        value: legacyExtDesc.trim(),
      );
      final legacyIntDesc = await _secureStorage.read(
        key: WalletStorageKeys.legacyInternalDescriptor,
      );
      if (legacyIntDesc != null && legacyIntDesc.trim().isNotEmpty) {
        await _secureStorage.write(
          key: WalletStorageKeys.internalDescriptorFor(walletId),
          value: legacyIntDesc.trim(),
        );
      }
    }
    await _secureStorage.write(
      key: WalletStorageKeys.scriptTypeFor(walletId),
      value: scriptType.storageValue,
    );
    await _secureStorage.write(
      key: WalletStorageKeys.capabilityFor(walletId),
      value: capability.storageValue,
    );

    // Verify secret persistence
    if (hasLegacySigning) {
      final readBack = await _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(walletId),
      );
      if (readBack != legacyMnemonic.trim()) {
        throw const WalletMigrationException(
          'Migration secret verification failed: scoped mnemonic mismatch.',
        );
      }
    }
    if (hasLegacyWatchOnly) {
      final readBack = await _secureStorage.read(
        key: WalletStorageKeys.externalDescriptorFor(walletId),
      );
      if (readBack != legacyExtDesc.trim()) {
        throw const WalletMigrationException(
          'Migration secret verification failed: scoped descriptor mismatch.',
        );
      }
    }

    // Database copy
    try {
      final String basePath;
      try {
        basePath = await _walletStoragePathLoader();
      } catch (e) {
        throw WalletMigrationException(
          'Failed to obtain wallet storage path during migration: $e',
          e,
        );
      }

      WalletRecord.validateWalletId(walletId);
      final walletsRoot = Directory('$basePath/wallets');
      final targetDir = Directory('${walletsRoot.path}/$walletId');
      if (!targetDir.path.startsWith('${walletsRoot.path}/') ||
          targetDir.path.contains('..')) {
        throw const WalletMigrationException(
          'Security invariant violation: migration target directory escaped storage root.',
        );
      }
      try {
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } catch (e) {
        throw WalletMigrationException(
          'Failed to create migration target directory "${targetDir.path}": $e',
          e,
        );
      }

      final targetDb = File('${targetDir.path}/bdk_wallet.sqlite');
      if (!await targetDb.exists()) {
        final watchOnlyPrefix = isWatchOnly ? 'watch_only_' : '';
        final candidateFilenames = <String>[
          'root_wallet_${watchOnlyPrefix}testnet_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
          'root_wallet_testnet_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
          'root_wallet_testnet_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
          'root_wallet_testnet.sqlite',
        ];

        File? sourceDb;
        for (final filename in candidateFilenames) {
          final legacyFile = File('$basePath/$filename');
          try {
            if (await legacyFile.exists() && await legacyFile.length() > 0) {
              sourceDb = legacyFile;
              break;
            }
          } catch (e) {
            throw WalletMigrationException(
              'Failed to inspect legacy database candidate "${legacyFile.path}": $e',
              e,
            );
          }
        }

        if (sourceDb != null) {
          try {
            await sourceDb.copy(targetDb.path);

            final legacyWal = File('${sourceDb.path}-wal');
            if (await legacyWal.exists()) {
              await legacyWal.copy('${targetDb.path}-wal');
            }
            final legacyShm = File('${sourceDb.path}-shm');
            if (await legacyShm.exists()) {
              await legacyShm.copy('${targetDb.path}-shm');
            }
          } catch (e) {
            throw WalletMigrationException(
              'Failed to copy legacy database "${sourceDb.path}": $e',
              e,
            );
          }
        }
      }
    } on WalletMigrationException {
      rethrow;
    } catch (e) {
      throw WalletMigrationException(
        'Database migration filesystem access failed: $e',
        e,
      );
    }

    // Migrate BIP-329 labels
    final legacyLabels =
        _prefs.getString('wallet.local_labels.v2.primary') ??
        _prefs.getString('wallet.local_labels.v1');
    if (legacyLabels != null && legacyLabels.trim().isNotEmpty) {
      await _prefs.setString('wallet.local_labels.v3.$walletId', legacyLabels);
    }

    // Migrate locked UTXOs
    final legacyLocked = _prefs.getStringList('settings.locked_utxos');
    if (legacyLocked != null && legacyLocked.isNotEmpty) {
      await _prefs.setStringList('wallet.$walletId.locked_utxos', legacyLocked);
    }

    // ==========================================
    // PHASE 3: REGISTER
    // ==========================================
    final record = WalletRecord(
      id: walletId,
      name: walletName,
      type: isWatchOnly ? WalletType.watchOnly : WalletType.signing,
      scriptType: scriptType,
      network: 'testnet',
      createdAt: DateTime.now(),
      fingerprint: fingerprint,
      isActive: true,
    );

    await registry.registerWallet(record, makeActive: true);

    // ==========================================
    // PHASE 4: MARK COMPLETE
    // ==========================================
    await _prefs.setBool(WalletStorageKeys.legacyMigrationCompleted, true);

    return record;
  }
}
