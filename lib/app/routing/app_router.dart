import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/features/receive/presentation/pages/receive_page.dart';
import 'package:root_wallet/features/send/presentation/pages/confirm_send_page.dart';
import 'package:root_wallet/features/send/presentation/pages/send_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/about_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/security_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/settings_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/create_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/restore_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/wallet_home_page.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.walletHome:
        return _page(settings, const WalletHomePage());
      case AppRoutes.createWallet:
        return _page(settings, const CreateWalletPage());
      case AppRoutes.backupSeed:
        return _page(settings, const BackupSeedPage());
      case AppRoutes.restoreWallet:
        return _page(settings, const RestoreWalletPage());
      case AppRoutes.send:
        return _page(settings, const SendPage());
      case AppRoutes.confirmSend:
        return _page(settings, const ConfirmSendPage());
      case AppRoutes.receive:
        return _page(settings, const ReceivePage());
      case AppRoutes.settings:
        return _page(settings, const SettingsPage());
      case AppRoutes.security:
        return _page(settings, const SecurityPage());
      case AppRoutes.about:
        return _page(settings, const AboutPage());
      default:
        return _page(settings, const WalletHomePage());
    }
  }

  static MaterialPageRoute<void> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<void>(settings: settings, builder: (_) => child);
  }
}
