import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/services/descriptor_validator.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_storage_cleaner.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_capability.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
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
    String? walletId,
  }) : _secureStorage = secureStorage,
       _walletStoragePathLoader = walletStoragePathLoader,
       _preferencesLoader = preferencesLoader,
       _allowCustomEsploraEndpoint = allowCustomEsploraEndpoint,
       _walletId = walletId;

  static const _customEsploraEndpointKey = 'settings.custom_esplora_endpoint';
  static const _network = bdk.Network.testnet;
  static const _networkKind = bdk.NetworkKind.test;

  final SecureStorage _secureStorage;
  final Future<String> Function() _walletStoragePathLoader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final bool _allowCustomEsploraEndpoint;
  final String? _walletId;

  String? get walletId => _walletId;

  bdk.Mnemonic? _mnemonic;
  bdk.DescriptorSecretKey? _descriptorSecretKey;
  bdk.Persister? _persister;
  bdk.Wallet? _wallet;
  bdk.Descriptor? _externalDescriptor;
  bdk.Descriptor? _internalDescriptor;
  Future<bdk.Wallet>? _walletFuture;
  int _activeEsploraIndex = 0;
  String? _customEsploraEndpoint;
  List<String> _esploraEndpoints = const <String>[];
  bool _endpointsLoaded = false;
  String? _lastBackendFailure;
  DateTime? _lastBackendFailureAt;
  bool _isDecoyActive = false;

  bool get isDecoyActive => _isDecoyActive;

  void setDecoyActive(bool active) {
    if (_isDecoyActive != active) {
      _isDecoyActive = active;
      _resetSession();
    }
  }

  final List<String> _baseEsploraEndpoints = List<String>.unmodifiable(
    AppConstants.testnetEsploraFallbackUrls,
  );

  Future<WalletCapability> getCapability() async {
    if (_walletId != null) {
      final stored = await _secureStorage.read(
        key: WalletStorageKeys.capabilityFor(_walletId),
      );
      if (stored != null && stored.trim().isNotEmpty) {
        return WalletCapability.fromStorageValue(stored);
      }
      final mnemonic = await _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(_walletId),
      );
      if (mnemonic != null && mnemonic.trim().isNotEmpty) {
        return WalletCapability.signing;
      }
      final extDesc = await _secureStorage.read(
        key: WalletStorageKeys.externalDescriptorFor(_walletId),
      );
      if (extDesc != null && extDesc.trim().isNotEmpty) {
        return WalletCapability.watchOnly;
      }
      throw StateError('Wallet "$_walletId" capability and secrets missing.');
    }

    final stored = await _secureStorage.read(
      key: WalletStorageKeys.walletCapability,
    );
    if (stored != null) {
      return WalletCapability.fromStorageValue(stored);
    }
    final mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
    if (mnemonic != null && mnemonic.trim().isNotEmpty) {
      return WalletCapability.signing;
    }
    final extDesc = await _secureStorage.read(
      key: WalletStorageKeys.externalDescriptor,
    );
    if (extDesc != null && extDesc.trim().isNotEmpty) {
      return WalletCapability.watchOnly;
    }
    return WalletCapability.signing;
  }

  Future<WalletCreationResult> createWallet({
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletId,
    String? walletName,
  }) {
    return _guard('create wallet', () async {
      final phrase = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();
      final id = walletId ?? _walletId ?? WalletRecord.generateId();

      // Sensitive seed material must stay in flutter_secure_storage only.
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

      // Legacy single-wallet fallback (ONLY when both _walletId and walletId are null)
      if (_walletId == null && walletId == null) {
        await _secureStorage.write(
          key: WalletStorageKeys.mnemonic,
          value: phrase,
        );
        await _secureStorage.write(
          key: WalletStorageKeys.scriptType,
          value: scriptType.storageValue,
        );
        await _secureStorage.write(
          key: WalletStorageKeys.walletCapability,
          value: WalletCapability.signing.storageValue,
        );
        await _secureStorage.delete(key: WalletStorageKeys.externalDescriptor);
        await _secureStorage.delete(key: WalletStorageKeys.internalDescriptor);
      }

      await _resetSession();

      final walletDirectory = await _walletStoragePathLoader();
      final isolatedDir = Directory('$walletDirectory/wallets/$id');
      if (await isolatedDir.exists()) {
        await isolatedDir.delete(recursive: true);
      }
      await isolatedDir.create(recursive: true);

      final identity = _identityFromMnemonic(phrase, scriptType, id: id);
      final record = WalletRecord(
        id: id,
        name: walletName ?? 'Main Wallet',
        type: WalletType.signing,
        scriptType: scriptType,
        network: _network.name,
        createdAt: DateTime.now(),
        fingerprint: identity.fingerprint,
        isActive: true,
      );

      final prefs = await _preferencesLoader();
      final registry = WalletRegistry(prefs);
      if (!registry.getWallets().any((w) => w.id == id)) {
        await registry.registerWallet(record, makeActive: true);
      }

      return WalletCreationResult(
        walletIdentity: identity,
        recoveryPhrase: phrase,
        walletRecord: record,
      );
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

  Future<List<bdk.LocalOutput>> getUtxos() {
    return _guard('get UTXOs', () async {
      final wallet = await _loadWallet();
      return wallet.listUnspent();
    });
  }

  Future<String> bumpFee({
    required String txidHex,
    required int newFeeRateSatVb,
  }) {
    return _guard('bump transaction fee', () async {
      final capability = await getCapability();
      if (capability.isWatchOnly) {
        throw StateError('Watch-only wallets cannot sign or bump transaction fees.');
      }
      final wallet = await _loadWallet();
      final txid = bdk.Txid.fromString(hex: txidHex);
      final feeRate = bdk.FeeRate.fromSatPerVb(satVb: newFeeRateSatVb);
      final builder = bdk.BumpFeeTxBuilder(txid: txid, feeRate: feeRate);
      final psbt = builder.finish(wallet: wallet);
      try {
        final isFinalized = wallet.sign(psbt: psbt, signOptions: null);
        if (!isFinalized) {
          throw StateError('Transaction could not be finalized.');
        }
        final transaction = psbt.extractTx();
        return await broadcastTransaction(transaction);
      } finally {
        psbt.dispose();
      }
    });
  }

  Future<String?> getMnemonic() async {
    final capability = await getCapability();
    if (capability.isWatchOnly) {
      return null;
    }
    if (_walletId != null) {
      return _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(_walletId),
      );
    }
    return _secureStorage.read(key: WalletStorageKeys.mnemonic);
  }

  Future<bool> hasWallet() async {
    if (_walletId != null) {
      final mnemonic = await _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(_walletId),
      );
      if (mnemonic != null && mnemonic.trim().isNotEmpty) {
        return true;
      }
      final extDesc = await _secureStorage.read(
        key: WalletStorageKeys.externalDescriptorFor(_walletId),
      );
      return extDesc != null && extDesc.trim().isNotEmpty;
    }
    final mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
    if (mnemonic != null && mnemonic.trim().isNotEmpty) {
      return true;
    }
    final extDesc = await _secureStorage.read(
      key: WalletStorageKeys.externalDescriptor,
    );
    return extDesc != null && extDesc.trim().isNotEmpty;
  }

  Future<WalletIdentity> restoreWallet({
    required String mnemonic,
    WalletScriptType scriptType = WalletScriptType.nativeSegwit,
    String? walletId,
    String? walletName,
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
      final id = walletId ?? _walletId ?? WalletRecord.generateId();

      // Scoped secure storage
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

      // Legacy single-wallet fallback (ONLY when both _walletId and walletId are null)
      if (_walletId == null && walletId == null) {
        await _secureStorage.write(
          key: WalletStorageKeys.mnemonic,
          value: phrase,
        );
        await _secureStorage.write(
          key: WalletStorageKeys.scriptType,
          value: scriptType.storageValue,
        );
        await _secureStorage.write(
          key: WalletStorageKeys.walletCapability,
          value: WalletCapability.signing.storageValue,
        );
        await _secureStorage.delete(key: WalletStorageKeys.externalDescriptor);
        await _secureStorage.delete(key: WalletStorageKeys.internalDescriptor);
      }

      await _resetSession();

      final walletDirectory = await _walletStoragePathLoader();
      final isolatedDir = Directory('$walletDirectory/wallets/$id');
      if (await isolatedDir.exists()) {
        await isolatedDir.delete(recursive: true);
      }
      await isolatedDir.create(recursive: true);

      final identity = _identityFromMnemonic(phrase, scriptType, id: id);
      final record = WalletRecord(
        id: id,
        name: walletName ?? 'Restored Wallet',
        type: WalletType.signing,
        scriptType: scriptType,
        network: _network.name,
        createdAt: DateTime.now(),
        fingerprint: identity.fingerprint,
        isActive: true,
      );

      final prefs = await _preferencesLoader();
      final registry = WalletRegistry(prefs);
      if (!registry.getWallets().any((w) => w.id == id)) {
        await registry.registerWallet(record, makeActive: true);
      }

      return identity;
    });
  }

  Future<WalletIdentity> importWatchOnlyWallet({
    required String externalDescriptor,
    String? internalDescriptor,
    String? walletId,
    String? walletName,
  }) {
    return _guard('import watch-only wallet', () async {
      final validated = DescriptorValidator.validate(
        externalInput: externalDescriptor,
        internalInput: internalDescriptor,
      );
      final id = walletId ?? _walletId ?? WalletRecord.generateId();

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

      // Legacy single-wallet fallback (ONLY when both _walletId and walletId are null)
      if (_walletId == null && walletId == null) {
        await _secureStorage.write(
          key: WalletStorageKeys.walletCapability,
          value: WalletCapability.watchOnly.storageValue,
        );
        await _secureStorage.write(
          key: WalletStorageKeys.externalDescriptor,
          value: validated.externalDescriptor,
        );
        if (validated.internalDescriptor != null &&
            validated.internalDescriptor!.isNotEmpty) {
          await _secureStorage.write(
            key: WalletStorageKeys.internalDescriptor,
            value: validated.internalDescriptor!,
          );
        } else {
          await _secureStorage.delete(key: WalletStorageKeys.internalDescriptor);
        }
        await _secureStorage.write(
          key: WalletStorageKeys.scriptType,
          value: validated.scriptType.storageValue,
        );
        await _secureStorage.delete(key: WalletStorageKeys.mnemonic);
        // Note: NEVER delete decoyMnemonic
      }

      await _resetSession();

      final walletDirectory = await _walletStoragePathLoader();
      final isolatedDir = Directory('$walletDirectory/wallets/$id');
      if (await isolatedDir.exists()) {
        await isolatedDir.delete(recursive: true);
      }
      await isolatedDir.create(recursive: true);

      final fingerprint = validated.fingerprint;

      final record = WalletRecord(
        id: id,
        name: walletName ?? 'Watch-Only Wallet',
        type: WalletType.watchOnly,
        scriptType: validated.scriptType,
        network: _network.name,
        createdAt: DateTime.now(),
        fingerprint: fingerprint,
        isActive: true,
      );

      final prefs = await _preferencesLoader();
      final registry = WalletRegistry(prefs);
      if (!registry.getWallets().any((w) => w.id == id)) {
        await registry.registerWallet(record, makeActive: true);
      }

      return WalletIdentity(
        id: id,
        fingerprint: fingerprint,
        network: _network.name,
        capability: WalletCapability.watchOnly,
      );
    });
  }

  Future<void> resetWallet() {
    return _guard('reset wallet', () async {
      await _secureStorage.delete(key: WalletStorageKeys.mnemonic);
      await _secureStorage.delete(key: WalletStorageKeys.decoyMnemonic);
      await _secureStorage.delete(key: WalletStorageKeys.scriptType);
      await _secureStorage.delete(key: WalletStorageKeys.walletCapability);
      await _secureStorage.delete(key: WalletStorageKeys.externalDescriptor);
      await _secureStorage.delete(key: WalletStorageKeys.internalDescriptor);
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
      final prefs = await _preferencesLoader();
      final customUrl = prefs.getString('settings.custom_electrum_url');

      final electrumUrls = [
        if (customUrl != null) customUrl,
        'tcp://testnet.aranguren.org:51001',
        'tcp://testnet.qtornado.com:51001',
        'tcp://testnet.hsmiths.com:53011',
      ];

      Object? lastError;
      for (final url in electrumUrls) {
        final client = bdk.ElectrumClient(
          url: url,
          socks5: null,
          timeout: 10,
          retry: 3,
          validateDomain: false,
        );
        try {
          final estimate = client.estimateFee(number: targetBlocks);
          return estimate <= 0 ? 1.0 : estimate;
        } catch (error) {
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
      final prefs = await _preferencesLoader();
      final customUrl = prefs.getString('settings.custom_electrum_url');

      final electrumUrls = [
        if (customUrl != null) customUrl,
        'tcp://testnet.aranguren.org:51001',
        'tcp://testnet.qtornado.com:51001',
        'tcp://testnet.hsmiths.com:53011',
      ];

      Object? lastError;
      for (final url in electrumUrls) {
        final client = bdk.ElectrumClient(
          url: url,
          socks5: null,
          timeout: 10,
          retry: 3,
          validateDomain: false,
        );
        try {
          final txid = client.transactionBroadcast(tx: transaction);
          return txid.toString();
        } catch (error) {
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
    final scriptType = await _readWalletScriptType();
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
      scriptType: scriptType.displayName,
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
    WalletScriptType scriptType, {
    String? id,
  }) {
    final normalized = _normalizeMnemonic(mnemonic);
    String? fingerprint;
    try {
      final parsed = bdk.Mnemonic.fromString(mnemonic: normalized);
      final secKey = bdk.DescriptorSecretKey(
        networkKind: _networkKind,
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

    return WalletIdentity(
      id: id ?? _walletId ?? 'wallet_${_network.name}_${scriptType.storageValue}',
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
    final capability = await getCapability();
    if (capability.isWatchOnly) {
      final extDescStr = _walletId != null
          ? await _secureStorage.read(
              key: WalletStorageKeys.externalDescriptorFor(_walletId),
            )
          : await _secureStorage.read(
              key: WalletStorageKeys.externalDescriptor,
            );
      if (extDescStr == null || extDescStr.trim().isEmpty) {
        throw StateError(
          'Watch-only wallet ${_walletId ?? ""} not initialized. Import descriptor first.',
        );
      }
      final intDescStr = _walletId != null
          ? await _secureStorage.read(
              key: WalletStorageKeys.internalDescriptorFor(_walletId),
            )
          : await _secureStorage.read(
              key: WalletStorageKeys.internalDescriptor,
            );

      final externalDescriptor = bdk.Descriptor(
        descriptor: extDescStr,
        networkKind: _networkKind,
      );
      bdk.Descriptor? internalDescriptor;
      if (intDescStr != null && intDescStr.trim().isNotEmpty) {
        internalDescriptor = bdk.Descriptor(
          descriptor: intDescStr,
          networkKind: _networkKind,
        );
      }

      final databasePath = await _databasePath();
      final persister = bdk.Persister.newSqlite(path: databasePath);
      final databaseFile = File(databasePath);
      final hasExistingDatabase =
          await databaseFile.exists() && await databaseFile.length() > 0;

      final bdk.Wallet wallet;
      if (internalDescriptor != null) {
        wallet = hasExistingDatabase
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
      } else {
        wallet = hasExistingDatabase
            ? bdk.Wallet.loadSingle(
                descriptor: externalDescriptor,
                persister: persister,
                lookahead: AppConstants.walletAddressDiscoveryStopGap,
              )
            : bdk.Wallet.createSingle(
                descriptor: externalDescriptor,
                network: _network,
                persister: persister,
                lookahead: AppConstants.walletAddressDiscoveryStopGap,
              );
      }

      _mnemonic = null;
      _descriptorSecretKey = null;
      _externalDescriptor = externalDescriptor;
      _internalDescriptor = internalDescriptor;
      _persister = persister;
      return wallet;
    }

    String? mnemonic;
    if (_isDecoyActive) {
      mnemonic = await _secureStorage.read(
        key: WalletStorageKeys.decoyMnemonic,
      );
      if (mnemonic == null || mnemonic.trim().isEmpty) {
        mnemonic = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();
        await _secureStorage.write(
          key: WalletStorageKeys.decoyMnemonic,
          value: mnemonic,
        );
      }
    } else if (_walletId != null) {
      mnemonic = await _secureStorage.read(
        key: WalletStorageKeys.mnemonicFor(_walletId),
      );
    } else {
      mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
    }

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
    final walletDirectory = await _walletStoragePathLoader();
    if (_isDecoyActive) {
      final decoyDir = Directory('$walletDirectory/decoy');
      if (!await decoyDir.exists()) {
        await decoyDir.create(recursive: true);
      }
      return '${decoyDir.path}/bdk_wallet.sqlite';
    }

    if (_walletId != null) {
      final walletDir = Directory('$walletDirectory/wallets/$_walletId');
      if (!await walletDir.exists()) {
        await walletDir.create(recursive: true);
      }
      return '${walletDir.path}/bdk_wallet.sqlite';
    }

    final scriptType = await _readWalletScriptType();
    final capability = await getCapability();
    final prefix = _isDecoyActive ? 'decoy_' : '';
    final watchOnlyPrefix = capability.isWatchOnly ? 'watch_only_' : '';
    final versionedPath =
        '$walletDirectory/${prefix}root_wallet_${watchOnlyPrefix}${_network.name}_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite';
    final legacyPath =
        '$walletDirectory/${prefix}root_wallet_${_network.name}.sqlite';

    if (await File(versionedPath).exists()) {
      return versionedPath;
    }
    if (!capability.isWatchOnly && await File(legacyPath).exists()) {
      return legacyPath;
    }
    return versionedPath;
  }

  Future<void> _deleteWalletDatabase() async {
    final walletDirectory = await _walletStoragePathLoader();
    final prefixes = <String>['', 'decoy_'];
    final networkNames = <String>[_network.name, 'testnet', 'signet', 'mainnet'];

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
          targetPaths.add(
            '$walletDirectory/${prefix}root_wallet_watch_only_${net}_${scriptType.storageValue}_v${AppConstants.walletDatabaseSchemaVersion}.sqlite',
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

  /// Deletes all isolated database files and secure secrets for [targetWalletId].
  ///
  /// Leaves all other wallets completely untouched.
  Future<void> deleteWalletData(String targetWalletId) async {
    final cleaner = WalletStorageCleaner(
      secureStorage: _secureStorage,
      preferences: await _preferencesLoader(),
      walletStoragePathLoader: _walletStoragePathLoader,
    );
    await cleaner.deleteWalletData(targetWalletId);
  }

  /// Cleans up active BDK native pointers and session resources.
  void dispose() {
    _resetSession();
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
    if (_walletId != null) {
      final value = await _secureStorage.read(
        key: WalletStorageKeys.scriptTypeFor(_walletId),
      );
      if (value != null && value.trim().isNotEmpty) {
        return WalletScriptType.fromStorageValue(value);
      }
      throw StateError('Missing script type for wallet "$_walletId".');
    }
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
      final capability = await getCapability();
      String? mnemonic;
      String? externalDescriptor;
      String? internalDescriptor;

      if (capability.isWatchOnly) {
        externalDescriptor = await _secureStorage.read(
          key: WalletStorageKeys.externalDescriptor,
        );
        if (externalDescriptor == null || externalDescriptor.trim().isEmpty) {
          throw StateError(
            'Watch-only wallet not initialized. Import descriptor first.',
          );
        }
        internalDescriptor = await _secureStorage.read(
          key: WalletStorageKeys.internalDescriptor,
        );
      } else {
        if (_isDecoyActive) {
          mnemonic = await _secureStorage.read(
            key: WalletStorageKeys.decoyMnemonic,
          );
          if (mnemonic == null || mnemonic.trim().isEmpty) {
            mnemonic = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();
            await _secureStorage.write(
              key: WalletStorageKeys.decoyMnemonic,
              value: mnemonic,
            );
          }
        } else {
          mnemonic = await _secureStorage.read(key: WalletStorageKeys.mnemonic);
        }
        if (mnemonic == null || mnemonic.trim().isEmpty) {
          throw StateError('Wallet not initialized. Create or restore first.');
        }
      }

      final scriptType = await _readWalletScriptType();
      final databasePath = await _databasePath();

      // Reset the session on the main thread to prevent DB lock issues during sync
      await _resetSession();

      final prefs = await _preferencesLoader();
      final customElectrumUrl = prefs.getString('settings.custom_electrum_url');

      final params = IsolateSyncParams(
        mnemonic: mnemonic,
        isWatchOnly: capability.isWatchOnly,
        externalDescriptor: externalDescriptor,
        internalDescriptor: internalDescriptor,
        scriptType: scriptType,
        network: _network,
        networkKind: _networkKind,
        databasePath: databasePath,
        esploraEndpoints: _esploraEndpoints,
        activeEsploraIndex: _activeEsploraIndex,
        lookahead: AppConstants.walletAddressDiscoveryStopGap,
        parallelRequests: AppConstants.esploraRequestConcurrency,
        customElectrumUrl: customElectrumUrl,
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
    this.mnemonic,
    this.isWatchOnly = false,
    this.externalDescriptor,
    this.internalDescriptor,
    required this.scriptType,
    required this.network,
    required this.networkKind,
    required this.databasePath,
    required this.esploraEndpoints,
    required this.activeEsploraIndex,
    required this.lookahead,
    required this.parallelRequests,
    this.customElectrumUrl,
  });

  final String? mnemonic;
  final bool isWatchOnly;
  final String? externalDescriptor;
  final String? internalDescriptor;
  final WalletScriptType scriptType;
  final bdk.Network network;
  final bdk.NetworkKind networkKind;
  final String databasePath;
  final List<String> esploraEndpoints;
  final int activeEsploraIndex;
  final int lookahead;
  final int parallelRequests;
  final String? customElectrumUrl;
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
  final depth =
      chainHeight - chainPosition.confirmationBlockTime.blockId.height + 1;
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

Future<IsolateSyncResult> _performBackgroundSync(
  IsolateSyncParams params,
) async {
  bdk.Descriptor externalDescriptor;
  bdk.Descriptor? internalDescriptor;
  bdk.DescriptorSecretKey? descriptorSecretKey;
  bdk.Mnemonic? parsedMnemonic;

  if (params.isWatchOnly) {
    externalDescriptor = bdk.Descriptor(
      descriptor: params.externalDescriptor!,
      networkKind: params.networkKind,
    );
    if (params.internalDescriptor != null &&
        params.internalDescriptor!.trim().isNotEmpty) {
      internalDescriptor = bdk.Descriptor(
        descriptor: params.internalDescriptor!,
        networkKind: params.networkKind,
      );
    }
  } else {
    parsedMnemonic = bdk.Mnemonic.fromString(mnemonic: params.mnemonic!);
    descriptorSecretKey = bdk.DescriptorSecretKey(
      networkKind: params.networkKind,
      mnemonic: parsedMnemonic,
      password: null,
    );
    externalDescriptor = _createDescriptorStatic(
      secretKey: descriptorSecretKey,
      scriptType: params.scriptType,
      keychain: bdk.KeychainKind.external_,
      networkKind: params.networkKind,
    );
    internalDescriptor = _createDescriptorStatic(
      secretKey: descriptorSecretKey,
      scriptType: params.scriptType,
      keychain: bdk.KeychainKind.internal,
      networkKind: params.networkKind,
    );
  }

  final databaseFile = File(params.databasePath);
  final hasExistingDatabase =
      databaseFile.existsSync() && databaseFile.lengthSync() > 0;
  final persister = bdk.Persister.newSqlite(path: params.databasePath);

  bdk.Wallet? wallet;
  try {
    if (internalDescriptor != null) {
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
    } else {
      wallet = hasExistingDatabase
          ? bdk.Wallet.loadSingle(
              descriptor: externalDescriptor,
              persister: persister,
              lookahead: params.lookahead,
            )
          : bdk.Wallet.createSingle(
              descriptor: externalDescriptor,
              network: params.network,
              persister: persister,
              lookahead: params.lookahead,
            );
    }


    Object? lastError;
    bool syncSucceeded = false;
    final endpointCount = params.esploraEndpoints.length;
    var activeIndex = params.activeEsploraIndex;

    // Prioritize Electrum sync as it is faster, has connection timeouts, and is not rate-limited.
    final electrumUrls = [
      if (params.customElectrumUrl != null) params.customElectrumUrl!,
      'tcp://testnet.aranguren.org:51001',
      'tcp://testnet.qtornado.com:51001',
      'tcp://testnet.hsmiths.com:53011',
    ];

    for (final electrumUrl in electrumUrls) {
      bdk.ElectrumClient? client;
      bdk.Update? update;
      bdk.FullScanRequest? request;
      bdk.FullScanRequestBuilder? requestBuilder;
      try {
        client = bdk.ElectrumClient(
          url: electrumUrl,
          socks5: null,
          timeout: 5,
          retry: 2,
          validateDomain: false,
        );
        requestBuilder = wallet.startFullScan();
        request = requestBuilder.build();
        update = client.fullScan(
          request: request,
          stopGap: params.lookahead,
          batchSize: 10,
          fetchPrevTxouts: true,
        );
        wallet.applyUpdate(update: update);
        wallet.persist(persister: persister);
        syncSucceeded = true;
        activeIndex = endpointCount; // Special index indicating Electrum
        break;
      } catch (error) {
        lastError = error;
      } finally {
        update?.dispose();
        request?.dispose();
        requestBuilder?.dispose();
        client?.dispose();
      }
    }

    if (!syncSucceeded) {
      for (var offset = 0; offset < endpointCount; offset++) {
        final index = (activeIndex + offset) % endpointCount;
        final endpoint = params.esploraEndpoints[index];

        final isReachable = await _testHttpsEndpoint(endpoint);
        if (!isReachable) {
          lastError = StateError('HTTPS endpoint $endpoint not reachable');
          continue;
        }

        bdk.EsploraClient? client;
        bdk.Update? update;
        bdk.FullScanRequest? request;
        bdk.FullScanRequestBuilder? requestBuilder;
        try {
          client = bdk.EsploraClient(url: endpoint, proxy: null);
          requestBuilder = wallet.startFullScan();
          request = requestBuilder.build();
          update = client.fullScan(
            request: request,
            stopGap: params.lookahead,
            parallelRequests: params.parallelRequests,
          );
          wallet.applyUpdate(update: update);
          wallet.persist(persister: persister);
          syncSucceeded = true;
          activeIndex = index;
          break;
        } catch (error) {
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
        bdk.EsploraClient? client;
        try {
          client = bdk.EsploraClient(url: endpoint, proxy: null);
          chainHeight = client.getHeight();
        } catch (_) {
        } finally {
          client?.dispose();
        }
      }
    }

    final balance = wallet.balance();
    final confirmedSats = balance.confirmed.toSat();
    final pendingSats =
        balance.trustedPending.toSat() + balance.untrustedPending.toSat();

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

      txItems.add(
        IsolateTxItem(
          txId: txid.toString(),
          amountSats: amount,
          timestampMs: timestampMs,
          isIncoming: isIncoming,
          status: chainPosition is bdk.ConfirmedChainPosition
              ? 'confirmed'
              : 'pending',
          feeSats: details?.fee?.toSat(),
          confirmations: confirmations,
        ),
      );
    }

    final addressInfo = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    wallet.persist(persister: persister);

    return IsolateSyncResult(
      confirmedSats: confirmedSats,
      pendingSats: pendingSats,
      transactions: txItems,
      receiveAddress: addressInfo.address.toString(),
      syncSucceeded: syncSucceeded,
      syncErrorString: lastError?.toString(),
      newActiveIndex: activeIndex < params.esploraEndpoints.length
          ? activeIndex
          : params.activeEsploraIndex,
    );
  } finally {
    wallet?.dispose();
    persister.dispose();
    externalDescriptor.dispose();
    internalDescriptor?.dispose();
    descriptorSecretKey?.dispose();
    parsedMnemonic?.dispose();
  }
}


Future<IsolateSyncResult> _runSyncIsolate(IsolateSyncParams params) {
  return Isolate.run(
    () => _performBackgroundSync(params),
  ).timeout(const Duration(seconds: 60));
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
  } catch (_) {
    return false;
  }
}
