import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to initialize app state.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
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
