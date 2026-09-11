import 'dart:async';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/network/network_storage_keys.dart';
import 'package:root_wallet/core/network/network_transport_config.dart';
import 'package:root_wallet/features/wallet/data/services/bdk_wallet_service.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

/// Function signature for probing an Electrum server through a SOCKS5 proxy.
typedef ProxyConnectionTester = Future<bool> Function({
  required String electrumUrl,
  required String socks5Address,
  int timeoutSeconds,
});

/// Default connection tester using the real BDK Electrum client in Rust via FFI.
///
/// Applies the central Electrum TLS policy (domain validation strictly enforced for ssl://).
Future<bool> defaultElectrumProxyTester({
  required String electrumUrl,
  required String socks5Address,
  int timeoutSeconds = 5,
}) async {
  bdk.ElectrumClient? client;
  try {
    client = defaultElectrumClientFactory(
      url: electrumUrl,
      socks5: socks5Address,
      timeout: timeoutSeconds,
      retry: 1,
    );
    client.ping();
    return true;
  } finally {
    client?.dispose();
  }
}

/// Provider for the proxy connection tester (overridable in tests).
final proxyConnectionTesterProvider = Provider<ProxyConnectionTester>(
  (ref) => defaultElectrumProxyTester,
);

class NetworkTransportController extends AsyncNotifier<NetworkConfiguration> {
  @override
  Future<NetworkConfiguration> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);

    final modeString = prefs.getString(NetworkStorageKeys.transportMode);
    final transportMode = NetworkTransportMode.parsePersisted(modeString);

    final host = prefs.getString(NetworkStorageKeys.proxyHost);
    final port = prefs.getInt(NetworkStorageKeys.proxyPort);

    Socks5ProxyConfig? proxyConfig;
    if (host != null && host.trim().isNotEmpty && port != null && port > 0) {
      try {
        proxyConfig = Socks5ProxyConfig(
          host: host,
          port: port,
        );
      } catch (_) {
        proxyConfig = null;
      }
    }

    return NetworkConfiguration(
      transportMode: transportMode,
      proxyConfig: proxyConfig,
    );
  }

  /// Sets the transport mode directly (e.g. toggling back to direct connection).
  ///
  /// Switching from SOCKS5 to Direct requires explicit user intent.
  Future<void> setTransportMode(NetworkTransportMode mode) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final saved = await prefs.setString(NetworkStorageKeys.transportMode, mode.storageValue);
    if (!saved) {
      throw StateError('Failed to persist transport mode.');
    }

    final current = state.valueOrNull ?? const NetworkConfiguration();
    state = AsyncData(
      current.copyWith(
        transportMode: mode,
        clearProxyTestError: true,
      ),
    );
    ref.invalidate(bdkWalletServiceProvider);
  }

  /// Saves the SOCKS5 proxy configuration and optionally activates SOCKS5 mode.
  ///
  /// Non-secret values (host, port) are stored in [SharedPreferences].
  Future<void> saveProxyConfig(
    Socks5ProxyConfig config, {
    bool activate = true,
    bool verified = false,
  }) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final secureStorage = ref.read(secureStorageProvider);

    // Snapshot previous known-good state for best-effort rollback in case of persistence failure.
    final previousHost = prefs.getString(NetworkStorageKeys.proxyHost);
    final previousPort = prefs.getInt(NetworkStorageKeys.proxyPort);
    final previousMode = prefs.getString(NetworkStorageKeys.transportMode);

    // Clean up any legacy credential keys BEFORE writing new active proxy configuration.
    // If secureStorage.delete throws, preferences remain untouched and previous config is preserved.
    await prefs.remove('settings.network.proxy_username');
    await secureStorage.delete(key: 'secure.settings.network.proxy_password');

    try {
      // Persist proxy endpoint
      final hostSaved = await prefs.setString(NetworkStorageKeys.proxyHost, config.host);
      if (!hostSaved) {
        throw StateError('Failed to persist proxy host.');
      }
      final portSaved = await prefs.setInt(NetworkStorageKeys.proxyPort, config.port);
      if (!portSaved) {
        throw StateError('Failed to persist proxy port.');
      }

      // Persist transport mode LAST
      final mode = activate ? NetworkTransportMode.socks5 : NetworkTransportMode.direct;
      final modeSaved = await prefs.setString(NetworkStorageKeys.transportMode, mode.storageValue);
      if (!modeSaved) {
        throw StateError('Failed to persist transport mode.');
      }

      state = AsyncData(
        NetworkConfiguration(
          transportMode: mode,
          proxyConfig: config,
          isProxyVerified: verified,
        ),
      );
      ref.invalidate(bdkWalletServiceProvider);
    } catch (e) {
      // Best-effort rollback to the previous known-good configuration
      if (previousHost != null) {
        await prefs.setString(NetworkStorageKeys.proxyHost, previousHost);
      } else {
        await prefs.remove(NetworkStorageKeys.proxyHost);
      }
      if (previousPort != null) {
        await prefs.setInt(NetworkStorageKeys.proxyPort, previousPort);
      } else {
        await prefs.remove(NetworkStorageKeys.proxyPort);
      }
      if (previousMode != null) {
        await prefs.setString(NetworkStorageKeys.transportMode, previousMode);
      } else {
        await prefs.remove(NetworkStorageKeys.transportMode);
      }
      rethrow;
    }
  }

  /// Explicit user action to switch from SOCKS5 to Direct.
  Future<void> revertToDirect() async {
    await setTransportMode(NetworkTransportMode.direct);
  }

  /// Tests connectivity to an Electrum server through the configured SOCKS5 proxy
  /// using the real [bdk.ElectrumClient] via Rust FFI.
  ///
  /// Tests the EXACT runtime target: custom Electrum URL if configured, or default fallback.
  Future<bool> testConnection(Socks5ProxyConfig config) async {
    final tester = ref.read(proxyConnectionTesterProvider);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final customUrl = prefs.getString(NetworkStorageKeys.customElectrumUrl);
    final electrumUrls = resolveElectrumEndpoints(customUrl: customUrl);
    final electrumUrl = electrumUrls.first;

    try {
      final success = await tester(
        electrumUrl: electrumUrl,
        socks5Address: config.address,
        timeoutSeconds: 5,
      );

      final current = state.valueOrNull ?? const NetworkConfiguration();
      state = AsyncData(
        current.copyWith(
          isProxyVerified: success,
          clearProxyTestError: success,
          lastProxyTestError: success ? null : 'Probe ping failed.',
        ),
      );
      return success;
    } catch (error) {
      final current = state.valueOrNull ?? const NetworkConfiguration();
      state = AsyncData(
        current.copyWith(
          isProxyVerified: false,
          lastProxyTestError: error.toString(),
        ),
      );
      return false;
    }
  }
}

final networkTransportProvider =
    AsyncNotifierProvider<NetworkTransportController, NetworkConfiguration>(
  NetworkTransportController.new,
);
