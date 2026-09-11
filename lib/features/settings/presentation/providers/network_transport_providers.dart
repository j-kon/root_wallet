import 'dart:async';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/network/network_storage_keys.dart';
import 'package:root_wallet/core/network/network_transport_config.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

/// Function signature for probing an Electrum server through a SOCKS5 proxy.
typedef ProxyConnectionTester = Future<bool> Function({
  required String electrumUrl,
  required String socks5Address,
  int timeoutSeconds,
});

/// Default connection tester using the real BDK Electrum client in Rust via FFI.
Future<bool> defaultElectrumProxyTester({
  required String electrumUrl,
  required String socks5Address,
  int timeoutSeconds = 5,
}) async {
  bdk.ElectrumClient? client;
  try {
    client = bdk.ElectrumClient(
      url: electrumUrl,
      socks5: socks5Address,
      timeout: timeoutSeconds,
      retry: 1,
      validateDomain: false,
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
    final secureStorage = ref.watch(secureStorageProvider);

    final modeString = prefs.getString(NetworkStorageKeys.transportMode);
    final transportMode = NetworkTransportMode.fromString(modeString);

    final host = prefs.getString(NetworkStorageKeys.proxyHost);
    final port = prefs.getInt(NetworkStorageKeys.proxyPort);
    final username = prefs.getString(NetworkStorageKeys.proxyUsername);
    final password = await secureStorage.read(
      key: NetworkStorageKeys.proxyPassword,
    );

    Socks5ProxyConfig? proxyConfig;
    if (host != null && host.trim().isNotEmpty && port != null && port > 0) {
      try {
        proxyConfig = Socks5ProxyConfig(
          host: host,
          port: port,
          username: username,
          password: password,
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
    await prefs.setString(NetworkStorageKeys.transportMode, mode.storageValue);

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
  /// Non-secret values (host, port, username) are stored in [SharedPreferences].
  /// Passwords, if present, are stored strictly in [SecureStorage].
  Future<void> saveProxyConfig(
    Socks5ProxyConfig config, {
    bool activate = true,
    bool verified = false,
  }) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final secureStorage = ref.read(secureStorageProvider);

    // Persist non-secrets to SharedPreferences
    await prefs.setString(NetworkStorageKeys.proxyHost, config.host);
    await prefs.setInt(NetworkStorageKeys.proxyPort, config.port);

    if (config.username != null && config.username!.isNotEmpty) {
      await prefs.setString(NetworkStorageKeys.proxyUsername, config.username!);
    } else {
      await prefs.remove(NetworkStorageKeys.proxyUsername);
    }

    // Persist secret strictly to SecureStorage
    if (config.password != null && config.password!.isNotEmpty) {
      try {
        await secureStorage.write(
          key: NetworkStorageKeys.proxyPassword,
          value: config.password!,
        );
      } catch (error) {
        // If secure storage write fails, do not activate authenticated proxy
        throw StateError(
          'Failed to securely store proxy password. Authentication cannot be enabled.',
        );
      }
    } else {
      await secureStorage.delete(key: NetworkStorageKeys.proxyPassword);
    }

    final mode = activate ? NetworkTransportMode.socks5 : NetworkTransportMode.direct;
    await prefs.setString(NetworkStorageKeys.transportMode, mode.storageValue);

    state = AsyncData(
      NetworkConfiguration(
        transportMode: mode,
        proxyConfig: config,
        isProxyVerified: verified,
      ),
    );
    ref.invalidate(bdkWalletServiceProvider);
  }

  /// Explicit user action to switch from SOCKS5 to Direct.
  Future<void> revertToDirect() async {
    await setTransportMode(NetworkTransportMode.direct);
  }

  /// Tests connectivity to an Electrum server through the configured SOCKS5 proxy
  /// using the real [bdk.ElectrumClient] via Rust FFI.
  Future<bool> testConnection(Socks5ProxyConfig config) async {
    final tester = ref.read(proxyConnectionTesterProvider);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final customUrl = prefs.getString(NetworkStorageKeys.customElectrumUrl);
    final electrumUrl = customUrl ?? AppConstants.testnetElectrumUrl;

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
