import 'dart:convert';
import 'dart:io';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

class WalletSeedService {
  const WalletSeedService({
    required SecureStorage secureStorage,
    required Future<String> Function() walletStoragePathLoader,
  }) : _secureStorage = secureStorage,
       _walletStoragePathLoader = walletStoragePathLoader;

  static const _networkName = 'testnet';

  final SecureStorage _secureStorage;
  final Future<String> Function() _walletStoragePathLoader;

  Future<WalletIdentity> createWallet() async {
    final phrase = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();
    await _writeWalletSeed(phrase, WalletScriptType.nativeSegwit);
    await _deleteWalletDatabase();
    return _identityFromMnemonic(phrase, WalletScriptType.nativeSegwit);
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
    final databasePaths = <String>[
      '$walletDirectory/root_wallet_$_networkName.sqlite',
      '$walletDirectory/root_wallet_$_networkName'
          '_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
      for (final scriptType in WalletScriptType.values)
        '$walletDirectory/root_wallet_${_networkName}_${scriptType.storageValue}'
            '_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
    ];

    for (final databasePath in databasePaths) {
      for (final path in <String>[
        databasePath,
        '$databasePath-wal',
        '$databasePath-shm',
      ]) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
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
      recoveryPhrase: mnemonic,
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
