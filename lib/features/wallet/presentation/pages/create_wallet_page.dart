import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';

class CreateWalletPage extends ConsumerWidget {
  const CreateWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return AppScaffold(
      title: 'Create Wallet',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new wallet identity and secure it before first receive.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (state.errorMessage != null) ...[
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: state.isBusy ? 'Creating...' : 'Create',
              onPressed: () async {
                final created = await controller.createWallet();
                if (!context.mounted) {
                  return;
                }

                if (!created) {
                  return;
                }
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.backupSeed,
                  arguments: const BackupSeedPageArgs(
                    requireReauth: false,
                    isOnboardingFlow: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
