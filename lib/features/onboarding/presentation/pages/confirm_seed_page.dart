import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';

class ConfirmSeedPage extends ConsumerStatefulWidget {
  const ConfirmSeedPage({super.key});

  @override
  ConsumerState<ConfirmSeedPage> createState() => _ConfirmSeedPageState();
}

class _ConfirmSeedPageState extends ConsumerState<ConfirmSeedPage> {
  final Map<int, String> _answers = <int, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingControllerProvider.notifier).prepareSeedChallenge();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return AppScaffold(
      title: 'Confirm recovery phrase',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the requested words to confirm you backed up your phrase.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.errorMessage != null) ...[
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.challengeIndices.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final index in state.challengeIndices) ...[
                      TextField(
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: InputDecoration(
                          labelText: 'Word #$index',
                        ),
                        onChanged: (value) {
                          _answers[index] = value.trim();
                          controller.clearError();
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: state.isBusy ? 'Confirming...' : 'Confirm backup',
              onPressed: state.isBusy || state.challengeIndices.isEmpty
                  ? null
                  : () async {
                      final confirmed = await controller.confirmBackup(_answers);
                      if (!confirmed || !context.mounted) {
                        return;
                      }

                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.walletHome,
                        (route) => false,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
