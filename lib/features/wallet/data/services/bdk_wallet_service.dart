import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BdkWalletServiceException implements Exception {
  const BdkWalletServiceException(this.action, this.cause);

  final String action;
  final Object cause;

  @override
  String toString() => 'Unable to $action: $cause';
}

class BdkWalletService {
  BdkWalletService({
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
  static const bdk.Network _network = bdk.Network.testnet;

  final SecureStorage _secureStorage;
  final Future<String> Function() _walletStoragePathLoader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final bool _allowCustomEsploraEndpoint;

  bdk.Wallet? _wallet;
  bdk.Persister? _persister;
  bdk.Mnemonic? _mnemonic;
  bdk.DescriptorSecretKey? _descriptorSecretKey;
  bdk.Descriptor? _externalDescriptor;
  bdk.Descriptor? _internalDescriptor;
  Future<bdk.Wallet>? _walletFuture;
  int _activeEsploraIndex = 0;
  String? _customEsploraEndpoint;
  List<String> _esploraEndpoints = const <String>[];
  bool _endpointsLoaded = false;
  String? _lastBackendFailure;
  DateTime? _lastBackendFailureAt;
  final List<String> _baseEsploraEndpoints = List<String>.unmodifiable(
    AppConstants.testnetEsploraFallbackUrls,
  );

  Future<WalletIdentity> createWallet() {
    return _guard('create wallet', () async {
      final mnemonic = bdk.Mnemonic(wordCount: bdk.WordCount.words12);
      final phrase = mnemonic.toString();
      mnemonic.dispose();

      // Sensitive seed material must stay in flutter_secure_storage only.
      await _secureStorage.write(key: _mnemonicKey, value: phrase);
      await _secureStorage.write(
        key: _scriptTypeKey,
        value: WalletScriptType.nativeSegwit.storageValue,
      );

      await _resetSession();
      await _deleteWalletDatabase();
      await _loadWallet();

      return _identityFromMnemonic(phrase, WalletScriptType.nativeSegwit);
    });
  }

  Future<String> getAddress() {
    return _guard('generate receive address', () async {
      final wallet = await _loadWallet();
      final addressInfo = wallet.revealNextAddress(
        keychain: bdk.KeychainKind.external_,
      );
      await _persistWallet();
      return addressInfo.address.toString();
    });
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
  }) {
    return _guard('restore wallet', () async {
      final normalized = _normalizeMnemonic(mnemonic);
      _validateMnemonicShape(normalized);
      final parsed = bdk.Mnemonic.fromString(mnemonic: normalized);
      final phrase = parsed.toString();
      parsed.dispose();

      // Sensitive seed material must stay in flutter_secure_storage only.
      await _secureStorage.write(key: _mnemonicKey, value: phrase);
      await _secureStorage.write(
        key: _scriptTypeKey,
        value: scriptType.storageValue,
      );

      await _resetSession();
      await _deleteWalletDatabase();
      await _loadWallet();

      return _identityFromMnemonic(phrase, scriptType);
    });
  }

  Future<void> resetWallet() {
    return _guard('reset wallet', () async {
      await _secureStorage.delete(key: _mnemonicKey);
      await _secureStorage.delete(key: _scriptTypeKey);
      await _resetSession();
      await _deleteWalletDatabase();
    });
  }

  Future<void> syncWallet() {
    return _guard('sync wallet', () async {
      final wallet = await _loadWallet();
      await _withEsploraFailover<void>((client) {
        final requestBuilder = wallet.startFullScan();
        final request = requestBuilder.build();
        bdk.Update? update;
        try {
          update = client.fullScan(
            request: request,
            stopGap: AppConstants.walletAddressDiscoveryStopGap,
            parallelRequests: AppConstants.esploraRequestConcurrency,
          );
          wallet.applyUpdate(update: update);
          wallet.persist(persister: _requirePersister());
        } finally {
          update?.dispose();
          request.dispose();
          requestBuilder.dispose();
        }
      });
    });
  }

  Future<int> chainHeight() {
    return _guard(
      'read testnet chain height',
      () => _withEsploraFailover<int>((client) => client.getHeight()),
    );
  }

  Future<double> estimateFeeSatPerVbyte({int targetBlocks = 3}) {
    return _guard('estimate transaction fee', () async {
      final client = bdk.ElectrumClient(
        url: AppConstants.testnetElectrumUrl,
        socks5: null,
      );
      try {
        final estimate = client.estimateFee(number: targetBlocks);
        return estimate <= 0 ? 1 : estimate;
      } finally {
        client.dispose();
      }
    });
  }

  Future<String> broadcastTransaction(bdk.Transaction transaction) {
    return _guard('broadcast transaction', () async {
      final client = bdk.ElectrumClient(
        url: AppConstants.testnetElectrumUrl,
        socks5: null,
      );
      try {
        final txid = client.transactionBroadcast(tx: transaction);
        return txid.toString();
      } finally {
        client.dispose();
      }
    });
  }

  Future<bdk.Wallet> resolveWallet() {
    return _loadWallet();
  }

  Future<bdk.Network> resolveNetwork() async {
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
  }

  Future<T> _guard<T>(String action, FutureOr<T> Function() task) async {
    try {
      return await task();
    } on BdkWalletServiceException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        BdkWalletServiceException(action, error),
        stackTrace,
      );
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
      id: 'wallet_${_network.name}_${scriptType.storageValue}',
      fingerprint: fingerprint,
      network: _network.name,
    );
  }

  Future<void> _resetSession() async {
    _walletFuture = null;
    _wallet?.dispose();
    _persister?.dispose();
    _externalDescriptor?.dispose();
    _internalDescriptor?.dispose();
    _descriptorSecretKey?.dispose();
    _mnemonic?.dispose();
    _wallet = null;
    _persister = null;
    _externalDescriptor = null;
    _internalDescriptor = null;
    _descriptorSecretKey = null;
    _mnemonic = null;
  }

  Future<T> _withEsploraFailover<T>(
    T Function(bdk.EsploraClient client) task,
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
      final client = bdk.EsploraClient(url: endpoint, proxy: null);
      try {
        return task(client);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        _lastBackendFailure = '$endpoint: ${_summarizeBackendError(error)}';
        _lastBackendFailureAt = DateTime.now();
      } finally {
        client.dispose();
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

  Future<bdk.Wallet> _loadWallet() async {
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

  Future<bdk.Wallet> _createWalletFromStorage() async {
    final mnemonic = await _secureStorage.read(key: _mnemonicKey);
    if (mnemonic == null || mnemonic.trim().isEmpty) {
      throw StateError('Wallet not initialized. Create or restore first.');
    }

    final parsedMnemonic = bdk.Mnemonic.fromString(
      mnemonic: _normalizeMnemonic(mnemonic),
    );
    final scriptType = await _readWalletScriptType();
    final descriptorSecretKey = bdk.DescriptorSecretKey(
      network: _network,
      mnemonic: parsedMnemonic,
      password: null,
    );
    final externalDescriptor = _createDescriptor(
      secretKey: descriptorSecretKey,
      scriptType: scriptType,
      keychain: bdk.KeychainKind.external_,
    );
    final internalDescriptor = _createDescriptor(
      secretKey: descriptorSecretKey,
      scriptType: scriptType,
      keychain: bdk.KeychainKind.internal,
    );
    final databasePath = await _databasePath();
    final persister = bdk.Persister.newSqlite(path: databasePath);
    final databaseFile = File(databasePath);
    final hasExistingDatabase =
        await databaseFile.exists() && await databaseFile.length() > 0;

    final wallet = hasExistingDatabase
        ? bdk.Wallet.load(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            persister: persister,
            lookahead: AppConstants.walletAddressDiscoveryStopGap,
          )
        : bdk.Wallet(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            network: _network,
            persister: persister,
            lookahead: AppConstants.walletAddressDiscoveryStopGap,
          );

    _mnemonic = parsedMnemonic;
    _descriptorSecretKey = descriptorSecretKey;
    _externalDescriptor = externalDescriptor;
    _internalDescriptor = internalDescriptor;
    _persister = persister;
    return wallet;
  }

  Future<void> _persistWallet() async {
    final wallet = await _loadWallet();
    wallet.persist(persister: _requirePersister());
  }

  bdk.Persister _requirePersister() {
    final persister = _persister;
    if (persister == null) {
      throw StateError('Wallet persister is not initialized.');
    }
    return persister;
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

  bdk.Descriptor _createDescriptor({
    required bdk.DescriptorSecretKey secretKey,
    required WalletScriptType scriptType,
    required bdk.KeychainKind keychain,
  }) {
    return switch (scriptType) {
      WalletScriptType.legacy => bdk.Descriptor.newBip44(
        secretKey: secretKey,
        network: _network,
        keychainKind: keychain,
      ),
      WalletScriptType.nestedSegwit => bdk.Descriptor.newBip49(
        secretKey: secretKey,
        network: _network,
        keychainKind: keychain,
      ),
      WalletScriptType.nativeSegwit => bdk.Descriptor.newBip84(
        secretKey: secretKey,
        network: _network,
        keychainKind: keychain,
      ),
      WalletScriptType.taproot => bdk.Descriptor.newBip86(
        secretKey: secretKey,
        network: _network,
        keychainKind: keychain,
      ),
    };
  }
}
