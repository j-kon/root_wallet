import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';

class RestoreWalletPage extends ConsumerStatefulWidget {
  const RestoreWalletPage({super.key});

  @override
  ConsumerState<RestoreWalletPage> createState() => _RestoreWalletPageState();
}

class _RestoreWalletPageState extends ConsumerState<RestoreWalletPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return AppScaffold(
      title: 'Restore Wallet',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (state.errorMessage != null) ...[
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recovery phrase',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: state.isBusy ? 'Restoring...' : 'Restore',
              onPressed: () async {
                final phrase = _controller.text.trim();
                if (phrase.isEmpty) {
                  return;
                }

                final restored = await controller.restoreWallet(phrase);
                if (!context.mounted) {
                  return;
                }
                if (!restored) {
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
