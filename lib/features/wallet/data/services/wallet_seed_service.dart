import 'dart:convert';
import 'dart:io';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

/// Legacy service for single-wallet seed persistence.
///
/// RESTRICTED: Retained strictly for legacy backwards compatibility and legacy tests.
/// Modern and fresh-install flows route through [AddWalletService] to ensure
/// scoped keys (`wallet.<id>.*`), isolated directories (`wallets/<id>/`),
/// real BIP32 master fingerprints, and [WalletRegistry] integration.
///
/// The synthetic SHA256 fingerprints generated here are NEVER persisted into the modern [WalletRegistry].
class WalletSeedService {
  const WalletSeedService({
    required SecureStorage secureStorage,
    required Future<String> Function() walletStoragePathLoader,
  }) : _secureStorage = secureStorage,
       _walletStoragePathLoader = walletStoragePathLoader;

  static const _networkName = 'testnet';

  final SecureStorage _secureStorage;
  final Future<String> Function() _walletStoragePathLoader;

  Future<WalletCreationResult> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    final mnemonic = bdk.Mnemonic(wordCount: bdk.WordCount.words12);
    final phrase = mnemonic.toString();
    mnemonic.dispose();
    await _writeWalletSeed(phrase, scriptType);
    await _deleteWalletDatabase();
    final identity = _identityFromMnemonic(phrase, scriptType);
    return WalletCreationResult(
      walletIdentity: identity,
      recoveryPhrase: phrase,
    );
  }

  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    final phrase = _normalizeMnemonic(mnemonic);
    _validateMnemonicShape(phrase);
    try {
      final parsed = bdk.Mnemonic.fromString(mnemonic: phrase);
      parsed.dispose();
    } catch (_) {
      throw const FormatException('Invalid recovery phrase checksum.');
    }
    await _writeWalletSeed(phrase, scriptType);
    await _deleteWalletDatabase();
    return _identityFromMnemonic(phrase, scriptType);
  }

  Future<void> _writeWalletSeed(
    String phrase,
    WalletScriptType scriptType,
  ) async {
    await _secureStorage.write(key: WalletStorageKeys.mnemonic, value: phrase);
    await _secureStorage.write(
      key: WalletStorageKeys.scriptType,
      value: scriptType.storageValue,
    );
  }

  Future<void> _deleteWalletDatabase() async {
    final walletDirectory = await _walletStoragePathLoader();
    final prefixes = <String>['', 'decoy_'];
    final networkNames = <String>[_networkName, 'testnet', 'signet', 'mainnet'];

    final targetPaths = <String>{};
    for (final prefix in prefixes) {
      for (final net in networkNames) {
        targetPaths.add('$walletDirectory/${prefix}root_wallet_$net.sqlite');
        targetPaths.add(
          '$walletDirectory/${prefix}root_wallet_${net}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
        );
        for (final scriptType in WalletScriptType.values) {
          targetPaths.add(
            '$walletDirectory/${prefix}root_wallet_${net}_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
          );
        }
      }
    }

    for (final dbPath in targetPaths) {
      for (final path in <String>[
        dbPath,
        '$dbPath-wal',
        '$dbPath-shm',
      ]) {
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }

    final dir = Directory(walletDirectory);
    if (await dir.exists()) {
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File) {
            final filename = entity.uri.pathSegments.last;
            if (filename.contains('root_wallet') &&
                (filename.endsWith('.sqlite') ||
                    filename.endsWith('.sqlite-wal') ||
                    filename.endsWith('.sqlite-shm'))) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }
  }

  WalletIdentity _identityFromMnemonic(
    String mnemonic,
    WalletScriptType scriptType,
  ) {
    final fingerprint = sha256
        .convert(utf8.encode(mnemonic))
        .toString()
        .substring(0, 8)
        .toUpperCase();

    return WalletIdentity(
      id: 'wallet_${_networkName}_${scriptType.storageValue}',
      fingerprint: fingerprint,
      network: _networkName,
    );
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
