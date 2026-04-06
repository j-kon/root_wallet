import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/app/routing/main_shell.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';

class AppStartGate extends ConsumerWidget {
  const AppStartGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startState = ref.watch(appStartControllerProvider);
    final controller = ref.read(appStartControllerProvider.notifier);

    return startState.when(
      loading: () =>
          const AppScaffold(body: Loading(label: 'Preparing wallet...')),
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
