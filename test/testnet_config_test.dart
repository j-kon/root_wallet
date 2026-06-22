import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:bdk_dart/bdk_dart.dart' as bdk;

void main() {
  test('public network constants align with bdk Network.testnet', () {
    expect(AppConstants.networkDisplayName, 'Testnet');
    expect(AppConstants.bitcoinNetworkDisplayName, 'Bitcoin testnet');
    expect(
      AppConstants.testnetElectrumUrl,
      'tcp://testnet.aranguren.org:51001',
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
      greaterThanOrEqualTo(20),
    );
    expect(AppConstants.esploraRequestConcurrency, lessThanOrEqualTo(2));
    expect(AppConstants.esploraRequestTimeoutSeconds, greaterThanOrEqualTo(60));
  });

  test('verifies bdk.OutPoint and bdk.TxBuilder methods compile', () {
    final outpoint = bdk.OutPoint(txid: bdk.Txid.fromString(hex: '0000000000000000000000000000000000000000000000000000000000000000'), vout: 0);
    expect(outpoint.txid.toString(), '0000000000000000000000000000000000000000000000000000000000000000');
    expect(outpoint.vout, 0);
  });
}

