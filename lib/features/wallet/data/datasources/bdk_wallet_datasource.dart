import 'dart:convert';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';

class BdkWalletDatasource {
  BdkWalletDatasource({required SecureStorage secureStorage})
    : _secureStorage = secureStorage;

  static const _mnemonicKey = 'wallet.mnemonic';
  final SecureStorage _secureStorage;

  Wallet? _wallet;
  Future<Wallet>? _walletFuture;
  Blockchain? _blockchain;
  Future<Blockchain>? _blockchainFuture;

  static const Network _network = Network.testnet;

  Future<WalletIdentity> createWallet() async {
    final mnemonic = await Mnemonic.create(WordCount.words12);
    final phrase = mnemonic.toString();
    await _secureStorage.write(key: _mnemonicKey, value: phrase);

    await _resetSession();
    await _loadWallet();

    return _identityFromMnemonic(phrase);
  }

  Future<String> getAddress() async {
    final wallet = await _loadWallet();
    final addressInfo = wallet.getAddress(
      addressIndex: const AddressIndex.lastUnused(),
    );
    return addressInfo.address.toString();
  }

  Future<String?> getMnemonic() {
    return _secureStorage.read(key: _mnemonicKey);
  }

  Future<bool> hasWallet() async {
    final mnemonic = await _secureStorage.read(key: _mnemonicKey);
    return mnemonic != null && mnemonic.trim().isNotEmpty;
  }

  Future<WalletIdentity> restoreWallet({required String mnemonic}) async {
    final normalized = _normalizeMnemonic(mnemonic);
    final parsed = await Mnemonic.fromString(normalized);
    final phrase = parsed.toString();

    await _secureStorage.write(key: _mnemonicKey, value: phrase);

    await _resetSession();
    await _loadWallet();

    return _identityFromMnemonic(phrase);
  }

  Future<void> syncWallet() async {
    final wallet = await _loadWallet();
    final blockchain = await _loadBlockchain();
    await wallet.sync(blockchain: blockchain);
  }

  Future<Wallet> resolveWallet() {
    return _loadWallet();
  }

  Future<Blockchain> resolveBlockchain() {
    return _loadBlockchain();
  }

  Future<Network> resolveNetwork() async {
    return _network;
  }

  WalletIdentity _identityFromMnemonic(String mnemonic) {
    final fingerprint = sha256
        .convert(utf8.encode(mnemonic))
        .toString()
        .substring(0, 8)
        .toUpperCase();

    return WalletIdentity(
      id: 'wallet_${_network.name}',
      fingerprint: fingerprint,
      network: _network.name,
    );
  }

  Future<void> _resetSession() async {
    _wallet = null;
    _walletFuture = null;
    _blockchain = null;
    _blockchainFuture = null;
  }

  Future<Blockchain> _loadBlockchain() async {
    if (_blockchain != null) {
      return _blockchain!;
    }

    final inflight = _blockchainFuture;
    if (inflight != null) {
      return inflight;
    }

    final future = _createBlockchain();
    _blockchainFuture = future;
    try {
      final blockchain = await future;
      _blockchain = blockchain;
      return blockchain;
    } finally {
      _blockchainFuture = null;
    }
  }

  Future<Blockchain> _createBlockchain() {
    final config = BlockchainConfig.esplora(
      config: EsploraConfig(
        baseUrl: AppConstants.testnetEsploraUrl,
        stopGap: BigInt.from(20),
        concurrency: 4,
        timeout: BigInt.from(30),
      ),
    );
    return Blockchain.create(config: config);
  }

  Future<Wallet> _loadWallet() async {
    if (_wallet != null) {
      return _wallet!;
    }

    final inflight = _walletFuture;
    if (inflight != null) {
      return inflight;
    }

    final future = _createWalletFromStorage();
    _walletFuture = future;
    try {
      final wallet = await future;
      _wallet = wallet;
      return wallet;
    } finally {
      _walletFuture = null;
    }
  }

  Future<Wallet> _createWalletFromStorage() async {
    final mnemonic = await _secureStorage.read(key: _mnemonicKey);
    if (mnemonic == null || mnemonic.trim().isEmpty) {
      throw StateError('Wallet not initialized. Create or restore first.');
    }

    final parsedMnemonic = await Mnemonic.fromString(_normalizeMnemonic(mnemonic));
    final descriptorSecretKey = await DescriptorSecretKey.create(
      network: _network,
      mnemonic: parsedMnemonic,
    );
    final externalDescriptor = await Descriptor.newBip84(
      secretKey: descriptorSecretKey,
      network: _network,
      keychain: KeychainKind.externalChain,
    );
    final internalDescriptor = await Descriptor.newBip84(
      secretKey: descriptorSecretKey,
      network: _network,
      keychain: KeychainKind.internalChain,
    );

    return Wallet.create(
      descriptor: externalDescriptor,
      changeDescriptor: internalDescriptor,
      network: _network,
      databaseConfig: const DatabaseConfig.memory(),
    );
  }

  String _normalizeMnemonic(String mnemonic) {
    return mnemonic
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
  }
}
