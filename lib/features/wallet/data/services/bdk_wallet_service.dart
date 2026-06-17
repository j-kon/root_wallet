import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
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

  static const _customEsploraEndpointKey = 'wallet.custom_esplora_endpoint.v1';
  static const bdk.Network _network = bdk.Network.testnet;
  static const bdk.NetworkKind _networkKind = bdk.NetworkKind.test;

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
      final phrase = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();

      // Sensitive seed material must stay in flutter_secure_storage only.
      await _secureStorage.write(
        key: WalletStorageKeys.mnemonic,
        value: phrase,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.scriptType,
        value: WalletScriptType.nativeSegwit.storageValue,
      );

      await _resetSession();
      await _deleteWalletDatabase();

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
    return _secureStorage.read(key: WalletStorageKeys.mnemonic);
  }

  Future<bool> hasWallet() async {
    final mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
    return mnemonic != null && mnemonic.trim().isNotEmpty;
  }

  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
  }) {
    return _guard('restore wallet', () async {
      final normalized = _normalizeMnemonic(mnemonic);
      _validateMnemonicShape(normalized);
      try {
        final parsed = bdk.Mnemonic.fromString(mnemonic: normalized);
        parsed.dispose();
      } catch (_) {
        throw const FormatException('Invalid recovery phrase checksum.');
      }
      final phrase = normalized;

      // Sensitive seed material must stay in flutter_secure_storage only.
      await _secureStorage.write(
        key: WalletStorageKeys.mnemonic,
        value: phrase,
      );
      await _secureStorage.write(
        key: WalletStorageKeys.scriptType,
        value: scriptType.storageValue,
      );

      await _resetSession();
      await _deleteWalletDatabase();

      return _identityFromMnemonic(phrase, scriptType);
    });
  }

  Future<void> resetWallet() {
    return _guard('reset wallet', () async {
      await _secureStorage.delete(key: WalletStorageKeys.mnemonic);
      await _secureStorage.delete(key: WalletStorageKeys.scriptType);
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
      final electrumUrls = [
        'tcp://electrum.blockstream.info:50001',
        'tcp://testnet.qtornado.com:51001',
        'tcp://testnet.hsmiths.com:53011',
      ];

      Object? lastError;
      for (final url in electrumUrls) {
        print('DEBUG FEE: Trying to estimate fee via Electrum URL: $url');
        final client = bdk.ElectrumClient(
          url: url,
          socks5: null,
          timeout: 10,
          retry: 3,
          validateDomain: false,
        );
        try {
          final estimate = client.estimateFee(number: targetBlocks);
          print('DEBUG FEE: Successfully estimated fee via $url. Estimate: $estimate');
          return estimate <= 0 ? 1.0 : estimate;
        } catch (error) {
          print('DEBUG FEE: Fee estimation via $url failed: $error');
          lastError = error;
        } finally {
          client.dispose();
        }
      }

      if (lastError != null) {
        throw lastError;
      }
      return 1.0;
    });
  }

  Future<String> broadcastTransaction(bdk.Transaction transaction) {
    return _guard('broadcast transaction', () async {
      final electrumUrls = [
        'tcp://electrum.blockstream.info:50001',
        'tcp://testnet.qtornado.com:51001',
        'tcp://testnet.hsmiths.com:53011',
      ];

      Object? lastError;
      for (final url in electrumUrls) {
        print('DEBUG BROADCAST: Trying to broadcast via Electrum URL: $url');
        final client = bdk.ElectrumClient(
          url: url,
          socks5: null,
          timeout: 10,
          retry: 3,
          validateDomain: false,
        );
        try {
          final txid = client.transactionBroadcast(tx: transaction);
          print('DEBUG BROADCAST: Successfully broadcasted tx via $url. TXID: $txid');
          return txid.toString();
        } catch (error) {
          print('DEBUG BROADCAST: Broadcast via $url failed: $error');
          lastError = error;
        } finally {
          client.dispose();
        }
      }

      if (lastError != null) {
        throw lastError;
      }
      throw StateError('Broadcast failed: No active Electrum servers');
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
      recoveryPhrase: mnemonic,
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
    final mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
    if (mnemonic == null || mnemonic.trim().isEmpty) {
      throw StateError('Wallet not initialized. Create or restore first.');
    }

    final parsedMnemonic = bdk.Mnemonic.fromString(
      mnemonic: _normalizeMnemonic(mnemonic),
    );
    final scriptType = await _readWalletScriptType();
    final descriptorSecretKey = bdk.DescriptorSecretKey(
      networkKind: _networkKind,
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
    final value = await _secureStorage.read(key: WalletStorageKeys.scriptType);
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
        networkKind: _networkKind,
        keychainKind: keychain,
      ),
      WalletScriptType.nestedSegwit => bdk.Descriptor.newBip49(
        secretKey: secretKey,
        networkKind: _networkKind,
        keychainKind: keychain,
      ),
      WalletScriptType.nativeSegwit => bdk.Descriptor.newBip84(
        secretKey: secretKey,
        networkKind: _networkKind,
        keychainKind: keychain,
      ),
      WalletScriptType.taproot => bdk.Descriptor.newBip86(
        secretKey: secretKey,
        networkKind: _networkKind,
        keychainKind: keychain,
      ),
    };
  }

  Future<WalletOverviewData> loadWalletOverviewInBackground() async {
    return _guard('load wallet overview in background', () async {
      await _loadEndpointPreferences();
      final mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
      if (mnemonic == null || mnemonic.trim().isEmpty) {
        throw StateError('Wallet not initialized. Create or restore first.');
      }
      final scriptType = await _readWalletScriptType();
      final databasePath = await _databasePath();

      // Reset the session on the main thread to prevent DB lock issues during sync
      await _resetSession();

      final params = IsolateSyncParams(
        mnemonic: mnemonic,
        scriptType: scriptType,
        network: _network,
        networkKind: _networkKind,
        databasePath: databasePath,
        esploraEndpoints: _esploraEndpoints,
        activeEsploraIndex: _activeEsploraIndex,
        lookahead: AppConstants.walletAddressDiscoveryStopGap,
        parallelRequests: AppConstants.esploraRequestConcurrency,
      );

      final result = await _runSyncIsolate(params);

      // Update the active esplora index based on the result
      _activeEsploraIndex = result.newActiveIndex;

      return WalletOverviewData(
        confirmedSats: result.confirmedSats,
        pendingSats: result.pendingSats,
        transactions: result.transactions,
        receiveAddress: result.receiveAddress,
        syncSucceeded: result.syncSucceeded,
        syncError: result.syncErrorString,
      );
    });
  }
}

class IsolateSyncParams {
  const IsolateSyncParams({
    required this.mnemonic,
    required this.scriptType,
    required this.network,
    required this.networkKind,
    required this.databasePath,
    required this.esploraEndpoints,
    required this.activeEsploraIndex,
    required this.lookahead,
    required this.parallelRequests,
  });

  final String mnemonic;
  final WalletScriptType scriptType;
  final bdk.Network network;
  final bdk.NetworkKind networkKind;
  final String databasePath;
  final List<String> esploraEndpoints;
  final int activeEsploraIndex;
  final int lookahead;
  final int parallelRequests;
}

class IsolateTxItem {
  const IsolateTxItem({
    required this.txId,
    required this.amountSats,
    required this.timestampMs,
    required this.isIncoming,
    required this.status,
    this.feeSats,
    this.confirmations,
  });

  final String txId;
  final int amountSats;
  final int timestampMs;
  final bool isIncoming;
  final String status;
  final int? feeSats;
  final int? confirmations;
}

class IsolateSyncResult {
  const IsolateSyncResult({
    required this.confirmedSats,
    required this.pendingSats,
    required this.transactions,
    required this.receiveAddress,
    required this.syncSucceeded,
    required this.newActiveIndex,
    this.syncErrorString,
  });

  final int confirmedSats;
  final int pendingSats;
  final List<IsolateTxItem> transactions;
  final String receiveAddress;
  final bool syncSucceeded;
  final int newActiveIndex;
  final String? syncErrorString;
}

class WalletOverviewData {
  const WalletOverviewData({
    required this.confirmedSats,
    required this.pendingSats,
    required this.transactions,
    required this.receiveAddress,
    required this.syncSucceeded,
    this.syncError,
  });

  final int confirmedSats;
  final int pendingSats;
  final List<IsolateTxItem> transactions;
  final String receiveAddress;
  final bool syncSucceeded;
  final String? syncError;
}

bdk.Descriptor _createDescriptorStatic({
  required bdk.DescriptorSecretKey secretKey,
  required WalletScriptType scriptType,
  required bdk.KeychainKind keychain,
  required bdk.NetworkKind networkKind,
}) {
  return switch (scriptType) {
    WalletScriptType.legacy => bdk.Descriptor.newBip44(
        secretKey: secretKey,
        networkKind: networkKind,
        keychainKind: keychain,
      ),
    WalletScriptType.nestedSegwit => bdk.Descriptor.newBip49(
        secretKey: secretKey,
        networkKind: networkKind,
        keychainKind: keychain,
      ),
    WalletScriptType.nativeSegwit => bdk.Descriptor.newBip84(
        secretKey: secretKey,
        networkKind: networkKind,
        keychainKind: keychain,
      ),
    WalletScriptType.taproot => bdk.Descriptor.newBip86(
        secretKey: secretKey,
        networkKind: networkKind,
        keychainKind: keychain,
      ),
  };
}

int? _confirmationsStatic(bdk.ChainPosition chainPosition, int? chainHeight) {
  if (chainPosition is! bdk.ConfirmedChainPosition) {
    return 0;
  }
  if (chainHeight == null) {
    return null;
  }
  final depth = chainHeight - chainPosition.confirmationBlockTime.blockId.height + 1;
  return depth <= 0 ? 1 : depth;
}

int _timestampMsStatic(bdk.ChainPosition chainPosition) {
  if (chainPosition is bdk.ConfirmedChainPosition) {
    return chainPosition.confirmationBlockTime.confirmationTime * 1000;
  }
  if (chainPosition is bdk.UnconfirmedChainPosition &&
      chainPosition.timestamp != null) {
    return chainPosition.timestamp! * 1000;
  }
  return DateTime.now().millisecondsSinceEpoch;
}

Future<IsolateSyncResult> _performBackgroundSync(IsolateSyncParams params) async {
  print('DEBUG ISOLATE: Start _performBackgroundSync');
  final parsedMnemonic = bdk.Mnemonic.fromString(mnemonic: params.mnemonic);
  print('DEBUG ISOLATE: Parsed mnemonic');
  final descriptorSecretKey = bdk.DescriptorSecretKey(
    networkKind: params.networkKind,
    mnemonic: parsedMnemonic,
    password: null,
  );
  print('DEBUG ISOLATE: Created descriptorSecretKey');

  final externalDescriptor = _createDescriptorStatic(
    secretKey: descriptorSecretKey,
    scriptType: params.scriptType,
    keychain: bdk.KeychainKind.external_,
    networkKind: params.networkKind,
  );
  final internalDescriptor = _createDescriptorStatic(
    secretKey: descriptorSecretKey,
    scriptType: params.scriptType,
    keychain: bdk.KeychainKind.internal,
    networkKind: params.networkKind,
  );
  print('DEBUG ISOLATE: Created descriptors');

  final databaseFile = File(params.databasePath);
  final hasExistingDatabase = databaseFile.existsSync() && databaseFile.lengthSync() > 0;
  print('DEBUG ISOLATE: Checked database exists: $hasExistingDatabase (path: ${params.databasePath})');
  final persister = bdk.Persister.newSqlite(path: params.databasePath);
  print('DEBUG ISOLATE: Created persister');

  bdk.Wallet? wallet;
  try {
    print('DEBUG ISOLATE: Loading wallet...');
    wallet = hasExistingDatabase
        ? bdk.Wallet.load(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            persister: persister,
            lookahead: params.lookahead,
          )
        : bdk.Wallet(
            descriptor: externalDescriptor,
            changeDescriptor: internalDescriptor,
            network: params.network,
            persister: persister,
            lookahead: params.lookahead,
          );
    print('DEBUG ISOLATE: Wallet loaded successfully');

    Object? lastError;
    bool syncSucceeded = false;
    final endpointCount = params.esploraEndpoints.length;
    var activeIndex = params.activeEsploraIndex;
    print('DEBUG ISOLATE: Starting sync loop. Endpoint count: $endpointCount');

    for (var offset = 0; offset < endpointCount; offset++) {
      final index = (activeIndex + offset) % endpointCount;
      final endpoint = params.esploraEndpoints[index];
      print('DEBUG ISOLATE: Trying endpoint $index: $endpoint');

      print('DEBUG ISOLATE: Testing HTTPS reachability for $endpoint...');
      final isReachable = await _testHttpsEndpoint(endpoint);
      if (!isReachable) {
        print('DEBUG ISOLATE: HTTPS endpoint $endpoint is not reachable or TLS failed. Skipping.');
        lastError = StateError('HTTPS endpoint $endpoint not reachable / TLS handshake issue');
        continue;
      }

      bdk.EsploraClient? client;
      bdk.Update? update;
      bdk.FullScanRequest? request;
      bdk.FullScanRequestBuilder? requestBuilder;
      try {
        client = bdk.EsploraClient(url: endpoint, proxy: null);
        print('DEBUG ISOLATE: Created EsploraClient');
        requestBuilder = wallet.startFullScan();
        request = requestBuilder.build();
        print('DEBUG ISOLATE: Calling client.fullScan...');
        update = client.fullScan(
          request: request,
          stopGap: params.lookahead,
          parallelRequests: params.parallelRequests,
        );
        print('DEBUG ISOLATE: client.fullScan completed. Applying update...');
        wallet.applyUpdate(update: update);
        print('DEBUG ISOLATE: Update applied. Persisting wallet...');
        wallet.persist(persister: persister);
        print('DEBUG ISOLATE: Wallet persisted');
        syncSucceeded = true;
        activeIndex = index;
        break;
      } catch (error) {
        print('DEBUG ISOLATE: Endpoint $endpoint failed: $error');
        lastError = error;
      } finally {
        update?.dispose();
        request?.dispose();
        requestBuilder?.dispose();
        client?.dispose();
      }
    }

    if (!syncSucceeded) {
      print('DEBUG ISOLATE: Esplora sync failed or skipped. Trying TCP Electrum fallback...');
      final electrumUrls = [
        'tcp://electrum.blockstream.info:50001',
        'tcp://testnet.qtornado.com:51001',
        'tcp://testnet.hsmiths.com:53011',
      ];

      for (final electrumUrl in electrumUrls) {
        print('DEBUG ISOLATE: Trying Electrum fallback URL: $electrumUrl');
        bdk.ElectrumClient? client;
        bdk.Update? update;
        bdk.FullScanRequest? request;
        bdk.FullScanRequestBuilder? requestBuilder;
        try {
          client = bdk.ElectrumClient(
            url: electrumUrl,
            socks5: null,
            timeout: 10,
            retry: 3,
            validateDomain: false,
          );
          print('DEBUG ISOLATE: Created ElectrumClient for fallback');
          requestBuilder = wallet.startFullScan();
          request = requestBuilder.build();
          print('DEBUG ISOLATE: Calling ElectrumClient.fullScan...');
          update = client.fullScan(
            request: request,
            stopGap: params.lookahead,
            batchSize: 10,
            fetchPrevTxouts: true,
          );
          print('DEBUG ISOLATE: ElectrumClient.fullScan completed. Applying update...');
          wallet.applyUpdate(update: update);
          print('DEBUG ISOLATE: Update applied. Persisting wallet...');
          wallet.persist(persister: persister);
          print('DEBUG ISOLATE: Wallet persisted');
          syncSucceeded = true;
          activeIndex = endpointCount; // Special index to indicate Electrum fallback
          break;
        } catch (error) {
          print('DEBUG ISOLATE: Electrum fallback URL $electrumUrl failed: $error');
          lastError = error;
        } finally {
          update?.dispose();
          request?.dispose();
          requestBuilder?.dispose();
          client?.dispose();
        }
      }
    }

    int? chainHeight;
    if (syncSucceeded) {
      if (activeIndex < params.esploraEndpoints.length) {
        final endpoint = params.esploraEndpoints[activeIndex];
        print('DEBUG ISOLATE: Sync succeeded. Getting chain height from $endpoint...');
        bdk.EsploraClient? client;
        try {
          client = bdk.EsploraClient(url: endpoint, proxy: null);
          chainHeight = client.getHeight();
          print('DEBUG ISOLATE: Chain height: $chainHeight');
        } catch (e) {
          print('DEBUG ISOLATE: Failed to get chain height: $e');
        } finally {
          client?.dispose();
        }
      } else {
        print('DEBUG ISOLATE: Sync succeeded via Electrum. Chain height is null (not supported via ElectrumClient).');
      }
    } else {
      print('DEBUG ISOLATE: Sync failed on all endpoints.');
    }

    print('DEBUG ISOLATE: Reading balance...');
    final balance = wallet.balance();
    final confirmedSats = balance.confirmed.toSat();
    final pendingSats = balance.trustedPending.toSat() + balance.untrustedPending.toSat();
    print('DEBUG ISOLATE: Balance: $confirmedSats sats confirmed, $pendingSats sats pending');

    print('DEBUG ISOLATE: Reading transactions...');
    final bdkTxs = wallet.transactions();
    final List<IsolateTxItem> txItems = [];
    for (final canonicalTx in bdkTxs) {
      final txid = canonicalTx.transaction.computeTxid();
      final details = wallet.txDetails(txid: txid);
      final values = details == null
          ? wallet.sentAndReceived(tx: canonicalTx.transaction)
          : null;
      final receivedSats = (details?.received ?? values!.received).toSat();
      final sentSats = (details?.sent ?? values!.sent).toSat();
      final isIncoming = receivedSats >= sentSats;
      final amount = (receivedSats - sentSats).abs();
      if (amount == 0) continue;

      final chainPosition = details?.chainPosition ?? canonicalTx.chainPosition;
      final confirmations = _confirmationsStatic(chainPosition, chainHeight);
      final timestampMs = _timestampMsStatic(chainPosition);

      txItems.add(IsolateTxItem(
        txId: txid.toString(),
        amountSats: amount,
        timestampMs: timestampMs,
        isIncoming: isIncoming,
        status: chainPosition is bdk.ConfirmedChainPosition ? 'confirmed' : 'pending',
        feeSats: details?.fee?.toSat(),
        confirmations: confirmations,
      ));
    }
    print('DEBUG ISOLATE: Transactions count: ${txItems.length}');

    print('DEBUG ISOLATE: Revealing receive address...');
    final addressInfo = wallet.revealNextAddress(keychain: bdk.KeychainKind.external_);
    print('DEBUG ISOLATE: Receive address: ${addressInfo.address}');
    wallet.persist(persister: persister);

    print('DEBUG ISOLATE: Returning result');
    return IsolateSyncResult(
      confirmedSats: confirmedSats,
      pendingSats: pendingSats,
      transactions: txItems,
      receiveAddress: addressInfo.address.toString(),
      syncSucceeded: syncSucceeded,
      syncErrorString: lastError?.toString(),
      newActiveIndex: activeIndex < params.esploraEndpoints.length ? activeIndex : params.activeEsploraIndex,
    );
  } finally {
    print('DEBUG ISOLATE: Disposing resources...');
    wallet?.dispose();
    persister.dispose();
    externalDescriptor.dispose();
    internalDescriptor.dispose();
    descriptorSecretKey.dispose();
    parsedMnemonic.dispose();
    print('DEBUG ISOLATE: Disposed resources');
  }
}

Future<IsolateSyncResult> _runSyncIsolate(IsolateSyncParams params) {
  return Isolate.run(() => _performBackgroundSync(params))
      .timeout(const Duration(seconds: 60));
}

Future<bool> _testHttpsEndpoint(String url) async {
  try {
    final uri = Uri.parse(url);
    final testUri = uri.replace(
      path: '${uri.path.replaceAll(RegExp(r'/+$'), '')}/blocks/tip/height',
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    final request = await client.getUrl(testUri);
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain();
    return response.statusCode == 200;
  } catch (e, stack) {
    print('DEBUG ISOLATE: _testHttpsEndpoint Exception for $url: $e\n$stack');
    return false;
  }
}
