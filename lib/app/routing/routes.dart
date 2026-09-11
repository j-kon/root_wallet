abstract final class AppRoutes {
  static const walletHome = '/';
  static const welcome = '/welcome';
  static const createWallet = '/wallet/create';
  static const backupSeed = '/wallet/backup';
  static const confirmSeed = '/wallet/backup/confirm';
  static const restoreWallet = '/wallet/restore';
  static const importWatchOnly = '/wallet/import-watch-only';
  static const transactionDetails = '/wallet/transaction';
  static const transactions = '/transactions';

  static const send = '/send';
  static const reviewTransfer = '/send/review';
  static const confirmSend = '/send/confirm';
  static const sendSuccess = '/send/success';
  static const receive = '/receive';

  static const psbtImport = '/psbt/import';
  static const psbtInspect = '/psbt/inspect';
  static const psbtExport = '/psbt/export';

  static const settings = '/settings';
  static const wallets = '/settings/wallets';
  static const walletDetails = '/settings/wallets/details';
  static const addWallet = '/wallet/add';
  static const security = '/settings/security';
  static const diagnostics = '/settings/diagnostics';
  static const coinControl = '/settings/coin_control';
  static const connectionRouting = '/settings/connection_routing';
  static const bip329Labels = '/settings/labels';
  static const backupMetadata = '/settings/backup';
  static const about = '/settings/about';
  static const notifications = '/notifications';
}
