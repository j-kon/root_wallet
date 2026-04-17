abstract final class AppRoutes {
  static const walletHome = '/';
  static const welcome = '/welcome';
  static const createWallet = '/wallet/create';
  static const backupSeed = '/wallet/backup';
  static const confirmSeed = '/wallet/backup/confirm';
  static const restoreWallet = '/wallet/restore';
  static const transactionDetails = '/wallet/transaction';

  static const send = '/send';
  static const reviewTransfer = '/send/review';
  static const confirmSend = '/send/confirm';
  static const sendSuccess = '/send/success';
  static const receive = '/receive';

  static const settings = '/settings';
  static const security = '/settings/security';
  static const diagnostics = '/settings/diagnostics';
  static const about = '/settings/about';
}
