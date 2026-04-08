import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';

class BdkWalletDatasource {
  BdkWalletDatasource({
    required SecureStorage secureStorage,
    required Future<String> Function() walletStoragePathLoader,
  }) : _secureStorage = secureStorage,
       _walletStoragePathLoader = walletStoragePathLoader;

  static const _mnemonicKey = 'wallet.mnemonic';
  final SecureStorage _secureStorage;
  final Future<String> Function() _walletStoragePathLoader;

  Wallet? _wallet;
  Future<Wallet>? _walletFuture;
  Blockchain? _blockchain;
  Future<Blockchain>? _blockchainFuture;
  String? _blockchainEndpoint;
  int _activeEsploraIndex = 0;
  final List<String> _esploraEndpoints = List<String>.unmodifiable(
    AppConstants.testnetEsploraFallbackUrls,
  );

  static const Network _network = Network.testnet;

  Future<WalletIdentity> createWallet() async {
    final mnemonic = await Mnemonic.create(WordCount.words12);
    final phrase = mnemonic.toString();
    await _secureStorage.write(key: _mnemonicKey, value: phrase);

    await _deleteWalletDatabase();
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

    await _deleteWalletDatabase();
    await _resetSession();
    await _loadWallet();

    return _identityFromMnemonic(phrase);
  }

  Future<void> syncWallet() async {
    final wallet = await _loadWallet();
    await _withBlockchainFailover<void>(
      (blockchain) => wallet.sync(blockchain: blockchain),
    );
  }

  Future<int> chainHeight() {
    return _withBlockchainFailover<int>((blockchain) => blockchain.getHeight());
  }

  Future<double> estimateFeeSatPerVbyte({int targetBlocks = 3}) async {
    final feeRate = await _withBlockchainFailover<FeeRate>(
      (blockchain) => blockchain.estimateFee(target: BigInt.from(targetBlocks)),
    );
    return feeRate.satPerVb;
  }

  Future<String> broadcastTransaction(Transaction transaction) {
    return _withBlockchainFailover<String>(
      (blockchain) => blockchain.broadcast(transaction: transaction),
    );
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
    await _resetBlockchainState();
  }

  Future<void> _resetBlockchainState() async {
    _blockchain = null;
    _blockchainFuture = null;
    _blockchainEndpoint = null;
  }

  Future<Blockchain> _loadBlockchain({bool forceReload = false}) async {
    if (forceReload) {
      await _resetBlockchainState();
    }

    final endpoint = _currentEsploraEndpoint;
    if (_blockchain != null && _blockchainEndpoint == endpoint) {
      return _blockchain!;
    }

    final inflight = _blockchainFuture;
    if (inflight != null) {
      return inflight;
    }

    final future = _createBlockchain(baseUrl: endpoint);
    _blockchainFuture = future;
    try {
      final blockchain = await future;
      _blockchain = blockchain;
      _blockchainEndpoint = endpoint;
      return blockchain;
    } finally {
      _blockchainFuture = null;
    }
  }

  Future<Blockchain> _createBlockchain({required String baseUrl}) {
    final config = BlockchainConfig.esplora(
      config: EsploraConfig(
        baseUrl: baseUrl,
        stopGap: BigInt.from(20),
        concurrency: 4,
        timeout: BigInt.from(30),
      ),
    );
    return Blockchain.create(config: config);
  }

  Future<T> _withBlockchainFailover<T>(
    Future<T> Function(Blockchain blockchain) task,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    final endpointCount = _esploraEndpoints.length;
    if (endpointCount == 0) {
      throw StateError('No Esplora endpoints configured.');
    }

    for (var offset = 0; offset < endpointCount; offset++) {
      final index = (_activeEsploraIndex + offset) % endpointCount;
      _activeEsploraIndex = index;
      final blockchain = await _loadBlockchain(forceReload: offset > 0);
      try {
        return await task(blockchain);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(
        lastError,
        lastStackTrace ?? StackTrace.current,
      );
    }

    throw StateError('Blockchain operation failed.');
  }

  String get _currentEsploraEndpoint => _esploraEndpoints[_activeEsploraIndex];

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

    final parsedMnemonic = await Mnemonic.fromString(
      _normalizeMnemonic(mnemonic),
    );
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

    final databasePath = await _databasePath();
    return Wallet.create(
      descriptor: externalDescriptor,
      changeDescriptor: internalDescriptor,
      network: _network,
      databaseConfig: DatabaseConfig.sqlite(
        config: SqliteDbConfiguration(path: databasePath),
      ),
    );
  }

  Future<String> _databasePath() async {
    final walletDirectory = await _walletStoragePathLoader();
    final versionedPath =
        '$walletDirectory/root_wallet_${_network.name}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite';
    final legacyPath = '$walletDirectory/root_wallet_${_network.name}.sqlite';

    if (await File(versionedPath).exists()) {
      return versionedPath;
    }
    if (await File(legacyPath).exists()) {
      return legacyPath;
    }
    return versionedPath;
  }

  Future<void> _deleteWalletDatabase() async {
    final walletDirectory = await _walletStoragePathLoader();
    final databasePaths = <String>[
      '$walletDirectory/root_wallet_${_network.name}.sqlite',
      '$walletDirectory/root_wallet_${_network.name}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
    ];
    final companionPaths = <String>[];
    for (final databasePath in databasePaths) {
      companionPaths.addAll(<String>[
        databasePath,
        '$databasePath-wal',
        '$databasePath-shm',
      ]);
    }

    for (final path in companionPaths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _normalizeMnemonic(String mnemonic) {
    return mnemonic
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .join(' ');
  }
}
