abstract final class AppConstants {
  static const appName = 'Root Wallet';
  static const appTagline = 'Secure self-custody, without the noise.';
  static const networkDisplayName = 'Testnet4';
  static const bitcoinNetworkDisplayName = 'Bitcoin testnet4';
  static const defaultCurrency = 'BTC';
  static const satoshisPerBitcoin = 100000000;
  static const minPinLength = 6;
  static const minSendAmountSats = 546;
  static const splashMinimumDuration = Duration(milliseconds: 1800);
  static const supportUrl = 'https://support.rootwallet.app';
  static const walletDatabaseSchemaVersion = 1;
  static const walletSnapshotSchemaVersion = 1;
  static const mainnetEsploraUrl = 'https://blockstream.info/api';
  static const testnetEsploraUrl = 'https://mempool.space/testnet4/api';
  static const testnetExplorerBaseUrl = 'https://mempool.space/testnet4';
  static const testnetEsploraFallbackUrls = <String>[testnetEsploraUrl];

  static String testnetExplorerTxUrl(String txId) {
    return '$testnetExplorerBaseUrl/tx/$txId';
  }
}
