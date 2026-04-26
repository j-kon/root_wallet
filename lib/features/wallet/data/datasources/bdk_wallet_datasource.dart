import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BdkWalletDatasource {
  BdkWalletDatasource({
    required SecureStorage secureStorage,
    required Future<String> Function() walletStoragePathLoader,
    required Future<SharedPreferences> Function() preferencesLoader,
    required bool allowCustomEsploraEndpoint,
  }) : _secureStorage = secureStorage,
       _walletStoragePathLoader = walletStoragePathLoader,
       _preferencesLoader = preferencesLoader,
       _allowCustomEsploraEndpoint = allowCustomEsploraEndpoint;

  static const _mnemonicKey = 'wallet.mnemonic';
  static const _scriptTypeKey = 'wallet.script_type';
  static const _customEsploraEndpointKey = 'wallet.custom_esplora_endpoint.v1';
  final SecureStorage _secureStorage;
  final Future<String> Function() _walletStoragePathLoader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final bool _allowCustomEsploraEndpoint;

  Wallet? _wallet;
  Future<Wallet>? _walletFuture;
  Blockchain? _blockchain;
  Future<Blockchain>? _blockchainFuture;
  String? _blockchainEndpoint;
  int _activeEsploraIndex = 0;
  String? _customEsploraEndpoint;
  List<String> _esploraEndpoints = const <String>[];
  bool _endpointsLoaded = false;
  String? _lastBackendFailure;
  DateTime? _lastBackendFailureAt;
  final List<String> _baseEsploraEndpoints = List<String>.unmodifiable(
    AppConstants.testnetEsploraFallbackUrls,
  );

  // bdk_flutter 0.31.3 exposes public Bitcoin testnet as Network.testnet.
  // Keep BDK descriptors, Esplora sync, explorer links, and user-facing labels
  // on the same network so wallet history is queried from the correct chain.
  static const Network _network = Network.testnet;

  Future<WalletIdentity> createWallet() async {
    final mnemonic = await Mnemonic.create(WordCount.words12);
    final phrase = mnemonic.toString();
    await _secureStorage.write(key: _mnemonicKey, value: phrase);
    await _secureStorage.write(
      key: _scriptTypeKey,
      value: WalletScriptType.nativeSegwit.storageValue,
    );

    await _resetSession();
    await _deleteWalletDatabase();
    await _loadWallet();

    return _identityFromMnemonic(phrase, WalletScriptType.nativeSegwit);
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

  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) async {
    final normalized = _normalizeMnemonic(mnemonic);
    _validateMnemonicShape(normalized);
    final parsed = await Mnemonic.fromString(normalized);
    final phrase = parsed.toString();

    await _secureStorage.write(key: _mnemonicKey, value: phrase);
    await _secureStorage.write(
      key: _scriptTypeKey,
      value: scriptType.storageValue,
    );

    await _resetSession();
    await _deleteWalletDatabase();
    await _loadWallet();

    return _identityFromMnemonic(phrase, scriptType);
  }

  Future<void> resetWallet() async {
    await _secureStorage.delete(key: _mnemonicKey);
    await _secureStorage.delete(key: _scriptTypeKey);
    await _resetSession();
    await _deleteWalletDatabase();
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

  Future<WalletDiagnostics> diagnostics() async {
    await _loadEndpointPreferences();
    return WalletDiagnostics(
      networkLabel: AppConstants.networkDisplayName,
      bdkNetwork: _network.name,
      activeEsploraEndpoint: _currentEsploraEndpoint,
      configuredEsploraEndpoints: _esploraEndpoints,
      activeEsploraIndex: _activeEsploraIndex,
      customEsploraEndpoint: _customEsploraEndpoint,
      lastBackendFailure: _lastBackendFailure,
      lastBackendFailureAt: _lastBackendFailureAt,
      walletDatabasePath: await _databasePath(),
      walletExists: await hasWallet(),
    );
  }

  Future<void> rotateBackend() async {
    await _loadEndpointPreferences();
    if (_esploraEndpoints.length <= 1) {
      return;
    }
    _activeEsploraIndex = (_activeEsploraIndex + 1) % _esploraEndpoints.length;
    await _resetBlockchainState();
  }

  Future<void> setCustomBackend(String? endpoint) async {
    if (!_allowCustomEsploraEndpoint) {
      throw StateError('Custom Esplora endpoints are disabled.');
    }

    final normalized = _normalizeEndpoint(endpoint);
    final prefs = await _preferencesLoader();
    if (normalized == null) {
      await prefs.remove(_customEsploraEndpointKey);
    } else {
      await prefs.setString(_customEsploraEndpointKey, normalized);
    }

    _customEsploraEndpoint = normalized;
    _endpointsLoaded = true;
    _rebuildEndpointList();
    await _resetBlockchainState();
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
      id: 'wallet_${_network.name}_${scriptType.storageValue}',
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
    await _loadEndpointPreferences();
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
        stopGap: BigInt.from(AppConstants.walletAddressDiscoveryStopGap),
        concurrency: AppConstants.esploraRequestConcurrency,
        timeout: BigInt.from(AppConstants.esploraRequestTimeoutSeconds),
      ),
    );
    return Blockchain.create(config: config);
  }

  Future<T> _withBlockchainFailover<T>(
    Future<T> Function(Blockchain blockchain) task,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    await _loadEndpointPreferences();
    final endpointCount = _esploraEndpoints.length;
    if (endpointCount == 0) {
      throw StateError('No Esplora endpoints configured.');
    }

    for (var offset = 0; offset < endpointCount; offset++) {
      final index = (_activeEsploraIndex + offset) % endpointCount;
      _activeEsploraIndex = index;
      final endpoint = _currentEsploraEndpoint;
      final blockchain = await _loadBlockchain(forceReload: offset > 0);
      try {
        return await task(blockchain);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        _lastBackendFailure = '$endpoint: ${_summarizeBackendError(error)}';
        _lastBackendFailureAt = DateTime.now();
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

  Future<void> _loadEndpointPreferences() async {
    if (_endpointsLoaded) {
      return;
    }

    if (_allowCustomEsploraEndpoint) {
      final prefs = await _preferencesLoader();
      _customEsploraEndpoint = _normalizeEndpoint(
        prefs.getString(_customEsploraEndpointKey),
      );
    }

    _rebuildEndpointList();
    _endpointsLoaded = true;
  }

  void _rebuildEndpointList() {
    final endpoints = <String>[
      if (_customEsploraEndpoint != null) _customEsploraEndpoint!,
      ..._baseEsploraEndpoints,
    ];
    _esploraEndpoints = List<String>.unmodifiable(endpoints.toSet());
    if (_activeEsploraIndex >= _esploraEndpoints.length) {
      _activeEsploraIndex = 0;
    }
  }

  String? _normalizeEndpoint(String? endpoint) {
    final trimmed = endpoint?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Enter a valid Esplora URL.');
    }
    if (uri.scheme != 'https' && uri.host != 'localhost') {
      throw const FormatException('Use HTTPS unless testing localhost.');
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  String _summarizeBackendError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 180) {
      return text;
    }
    return '${text.substring(0, 180)}...';
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

    final parsedMnemonic = await Mnemonic.fromString(
      _normalizeMnemonic(mnemonic),
    );
    final scriptType = await _readWalletScriptType();
    final descriptorSecretKey = await DescriptorSecretKey.create(
      network: _network,
      mnemonic: parsedMnemonic,
    );
    final externalDescriptor = await _createDescriptor(
      secretKey: descriptorSecretKey,
      scriptType: scriptType,
      keychain: KeychainKind.externalChain,
    );
    final internalDescriptor = await _createDescriptor(
      secretKey: descriptorSecretKey,
      scriptType: scriptType,
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
    final scriptType = await _readWalletScriptType();
    final walletDirectory = await _walletStoragePathLoader();
    final versionedPath =
        '$walletDirectory/root_wallet_${_network.name}_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite';
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
      for (final scriptType in WalletScriptType.values)
        '$walletDirectory/root_wallet_${_network.name}_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
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

  Future<WalletScriptType> _readWalletScriptType() async {
    final value = await _secureStorage.read(key: _scriptTypeKey);
    return WalletScriptType.fromStorageValue(value);
  }

  Future<Descriptor> _createDescriptor({
    required DescriptorSecretKey secretKey,
    required WalletScriptType scriptType,
    required KeychainKind keychain,
  }) {
    return switch (scriptType) {
      WalletScriptType.legacy => Descriptor.newBip44(
        secretKey: secretKey,
        network: _network,
        keychain: keychain,
      ),
      WalletScriptType.nestedSegwit => Descriptor.newBip49(
        secretKey: secretKey,
        network: _network,
        keychain: keychain,
      ),
      WalletScriptType.nativeSegwit => Descriptor.newBip84(
        secretKey: secretKey,
        network: _network,
        keychain: keychain,
      ),
      WalletScriptType.taproot => Descriptor.newBip86(
        secretKey: secretKey,
        network: _network,
        keychain: keychain,
      ),
    };
  }
}
