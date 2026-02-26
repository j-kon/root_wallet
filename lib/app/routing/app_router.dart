import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/app_start_gate.dart';
import 'package:root_wallet/app/routing/main_shell.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/confirm_seed_page.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:root_wallet/features/send/presentation/pages/review_transfer_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/about_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/security_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/create_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/restore_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/transaction_details_page.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.walletHome:
        return _page(settings, const AppStartGate());
      case AppRoutes.welcome:
        return _page(settings, const WelcomePage());
      case AppRoutes.createWallet:
        return _page(settings, const CreateWalletPage());
      case AppRoutes.backupSeed:
        final args = settings.arguments;
        final options = args is BackupSeedPageArgs
            ? args
            : const BackupSeedPageArgs();
        return _page(
          settings,
          BackupSeedPage(
            requireReauth: options.requireReauth,
            isOnboardingFlow: options.isOnboardingFlow,
          ),
        );
      case AppRoutes.confirmSeed:
        return _page(settings, const ConfirmSeedPage());
      case AppRoutes.restoreWallet:
        return _page(settings, const RestoreWalletPage());
      case AppRoutes.transactionDetails:
        return _page(settings, const TransactionDetailsPage());
      case AppRoutes.send:
        return _page(settings, const MainShell(initialIndex: 2));
      case AppRoutes.reviewTransfer:
      case AppRoutes.confirmSend:
        return _page(settings, const ReviewTransferPage());
      case AppRoutes.receive:
        return _page(settings, const MainShell(initialIndex: 1));
      case AppRoutes.settings:
        return _page(settings, const MainShell(initialIndex: 3));
      case AppRoutes.security:
        return _page(settings, const SecurityPage());
      case AppRoutes.about:
        return _page(settings, const AboutPage());
      default:
        return _page(settings, const AppStartGate());
    }
  }

  static MaterialPageRoute<void> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<void>(settings: settings, builder: (_) => child);
  }
}
