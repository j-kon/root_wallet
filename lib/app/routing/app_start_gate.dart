import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/app_splash_screen.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/app/routing/main_shell.dart';

class AppStartGate extends ConsumerStatefulWidget {
  const AppStartGate({super.key});

  @override
  ConsumerState<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends ConsumerState<AppStartGate> {
  Timer? _minimumTimer;
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(AppConstants.splashMinimumDuration, () {
      if (mounted) {
        setState(() {
          _minimumSplashElapsed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startState = ref.watch(appStartControllerProvider);
    final controller = ref.read(appStartControllerProvider.notifier);

    if (startState.isLoading || !_minimumSplashElapsed) {
      return AppSplashScreen(
        statusLabel: startState.isLoading
            ? 'Preparing secure wallet...'
            : 'Opening wallet experience...',
      );
    }

    return startState.when(
      loading: () =>
          const AppSplashScreen(statusLabel: 'Preparing secure wallet...'),
      error: (error, _) => AppScaffold(
        body: EmptyState(
          title: 'Unable to initialize app state',
          message: 'Try loading the wallet again.',
          actionLabel: 'Retry',
          onAction: controller.refresh,
          icon: Icons.refresh_rounded,
        ),
      ),
      data: (state) {
        return switch (state.destination) {
          AppStartDestination.onboarding => const WelcomePage(),
          AppStartDestination.mainShell => const MainShell(),
          AppStartDestination.needsBackup => const MainShell(),
        };
      },
    );
  }
}
