import 'package:root_wallet/core/constants/app_constants.dart';

class WalletDiagnostics {
  const WalletDiagnostics({
    required this.networkLabel,
    required this.bdkNetwork,
    required this.activeEsploraEndpoint,
    required this.configuredEsploraEndpoints,
    required this.activeEsploraIndex,
    required this.customEsploraEndpoint,
    required this.lastBackendFailure,
    required this.lastBackendFailureAt,
    required this.walletDatabasePath,
    required this.walletExists,
  });

  final String networkLabel;
  final String bdkNetwork;
  final String activeEsploraEndpoint;
  final List<String> configuredEsploraEndpoints;
  final int activeEsploraIndex;
  final String? customEsploraEndpoint;
  final String? lastBackendFailure;
  final DateTime? lastBackendFailureAt;
  final String walletDatabasePath;
  final bool walletExists;

  String get backendFailoverState {
    if (configuredEsploraEndpoints.length <= 1) {
      return 'Single verified backend configured';
    }
    return 'Endpoint ${activeEsploraIndex + 1} of ${configuredEsploraEndpoints.length}';
  }

  Map<String, Object?> toJson({DateTime? cacheUpdatedAt, String? walletState}) {
    return <String, Object?>{
      'appNetworkLabel': networkLabel,
      'bdkNetwork': bdkNetwork,
      'activeEsploraEndpoint': activeEsploraEndpoint,
      'configuredEsploraEndpoints': configuredEsploraEndpoints,
      'activeEsploraIndex': activeEsploraIndex,
      'customEsploraEndpoint': customEsploraEndpoint,
      'lastBackendFailure': lastBackendFailure,
      'lastBackendFailureAt': lastBackendFailureAt?.toIso8601String(),
      'walletDatabasePath': walletDatabasePath,
      'walletExists': walletExists,
      'cacheUpdatedAt': cacheUpdatedAt?.toIso8601String(),
      'walletState': walletState,
      'explorerBaseUrl': AppConstants.testnetExplorerBaseUrl,
    };
  }
}
