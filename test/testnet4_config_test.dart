import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';

void main() {
  test('public network constants point at testnet4 user-facing surfaces', () {
    expect(AppConstants.networkDisplayName, 'Testnet4');
    expect(AppConstants.bitcoinNetworkDisplayName, 'Bitcoin testnet4');
    expect(
      AppConstants.testnetEsploraUrl,
      'https://mempool.space/testnet4/api',
    );
    expect(
      AppConstants.testnetExplorerTxUrl('abc123'),
      'https://mempool.space/testnet4/tx/abc123',
    );
  });
}
