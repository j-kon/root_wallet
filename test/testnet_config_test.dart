import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';

void main() {
  test('public network constants align with bdk Network.testnet', () {
    expect(AppConstants.networkDisplayName, 'Testnet');
    expect(AppConstants.bitcoinNetworkDisplayName, 'Bitcoin testnet');
    expect(
      AppConstants.testnetElectrumUrl,
      'ssl://electrum.blockstream.info:60002',
    );
    expect(
      AppConstants.testnetEsploraUrl,
      'https://blockstream.info/testnet/api',
    );
    expect(
      AppConstants.testnetExplorerTxUrl('abc123'),
      'https://mempool.space/testnet/tx/abc123',
    );
    expect(
      AppConstants.testnetEsploraFallbackUrls,
      contains('https://mempool.space/testnet/api'),
    );
    expect(
      AppConstants.walletAddressDiscoveryStopGap,
      greaterThanOrEqualTo(100),
    );
    expect(AppConstants.esploraRequestConcurrency, lessThanOrEqualTo(2));
    expect(AppConstants.esploraRequestTimeoutSeconds, greaterThanOrEqualTo(60));
  });
}
