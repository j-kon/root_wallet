abstract final class AppConstants {
  static const appName = 'Root Wallet';
  static const defaultCurrency = 'BTC';
  static const satoshisPerBitcoin = 100000000;
  static const minPinLength = 6;
  static const supportUrl = 'https://support.rootwallet.app';
  static const mainnetEsploraUrl = 'https://blockstream.info/api';
  static const testnetEsploraUrl = 'https://mempool.space/testnet/api';
  static const testnetEsploraFallbackUrls = <String>[
    testnetEsploraUrl,
    'https://blockstream.info/testnet/api',
  ];
}
