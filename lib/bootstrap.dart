import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/env/app_env.dart';
import 'package:root_wallet/app/routing/app_router.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/security/app_security_gate.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/app/theme/theme_mode_provider.dart';
import 'package:root_wallet/core/constants/app_constants.dart';

Future<void> bootstrap({AppEnv? env}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final overrides = <Override>[];
  if (env != null) {
    overrides.add(appEnvProvider.overrideWithValue(env));
  }

  runApp(ProviderScope(overrides: overrides, child: const RootWalletApp()));
}

class RootWalletApp extends ConsumerWidget {
  const RootWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp(
      title: AppConstants.appName,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      initialRoute: AppRoutes.walletHome,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) =>
          AppSecurityGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
