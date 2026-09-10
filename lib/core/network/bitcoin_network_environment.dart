import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/core/constants/app_constants.dart';

/// Supported Bitcoin network environments for Root Wallet.
/// Enforces strong separation between testnet, signet, and mainnet,
/// including storage directory namespaces and locked mainnet readiness.
enum BitcoinNetworkEnvironment {
  testnet(
    name: 'testnet',
    displayName: 'Testnet',
    addressPrefixes: ['tb1', '2', 'm', 'n'],
    bdkNetwork: bdk.Network.testnet,
    bdkNetworkKind: bdk.NetworkKind.test,
    defaultEsploraEndpoints: [
      AppConstants.mempoolTestnetEsploraUrl,
      AppConstants.blockstreamTestnetEsploraUrl,
    ],
  ),
  signet(
    name: 'signet',
    displayName: 'Signet',
    addressPrefixes: ['tb1', '2', 'm', 'n'],
    bdkNetwork: bdk.Network.signet,
    bdkNetworkKind: bdk.NetworkKind.test,
    defaultEsploraEndpoints: [
      'https://mempool.space/signet/api',
    ],
  ),
  mainnet(
    name: 'mainnet',
    displayName: 'Mainnet',
    addressPrefixes: ['bc1', '1', '3'],
    bdkNetwork: bdk.Network.bitcoin,
    bdkNetworkKind: bdk.NetworkKind.main,
    defaultEsploraEndpoints: [
      'https://mempool.space/api',
      AppConstants.mainnetEsploraUrl,
    ],
  );

  const BitcoinNetworkEnvironment({
    required this.name,
    required this.displayName,
    required this.addressPrefixes,
    required this.bdkNetwork,
    required this.bdkNetworkKind,
    required this.defaultEsploraEndpoints,
  });

  final String name;
  final String displayName;
  final List<String> addressPrefixes;
  final bdk.Network bdkNetwork;
  final bdk.NetworkKind bdkNetworkKind;
  final List<String> defaultEsploraEndpoints;

  bool get isMainnet => this == BitcoinNetworkEnvironment.mainnet;

  /// Returns whether this network environment is permitted in the current application build.
  bool get isAllowed => !isMainnet || AppConstants.isMainnetAllowed;

  /// Asserts that the network environment is allowed to run.
  /// Throws [StateError] if mainnet is requested while disabled.
  void assertAllowed() {
    if (!isAllowed) {
      throw StateError(
        'Bitcoin Mainnet is locked and disabled in this security milestone build of Root Wallet. '
        'Root Wallet remains testnet-first until security hardening and independent audits are complete.',
      );
    }
  }

  /// Parses a network environment from name, defaulting to [testnet].
  static BitcoinNetworkEnvironment fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return BitcoinNetworkEnvironment.testnet;
    }
    final normalized = name.trim().toLowerCase();
    for (final env in BitcoinNetworkEnvironment.values) {
      if (env.name == normalized) {
        return env;
      }
    }
    if (normalized == 'bitcoin') {
      return BitcoinNetworkEnvironment.mainnet;
    }
    return BitcoinNetworkEnvironment.testnet;
  }

  /// Returns the isolated database directory namespace for this network.
  String databaseNamespace(String baseDirectory) {
    return '$baseDirectory/$name';
  }

  /// Validates whether the given Bitcoin address matches the active network's valid prefix.
  bool isValidAddressPrefix(String address) {
    final lower = address.trim().toLowerCase();
    return addressPrefixes.any((prefix) => lower.startsWith(prefix.toLowerCase()));
  }
}
