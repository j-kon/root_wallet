import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/widgets/copy_row.dart';

class BackupSeedPageArgs {
  const BackupSeedPageArgs({
    this.requireReauth = true,
    this.isOnboardingFlow = false,
  });

  final bool requireReauth;
  final bool isOnboardingFlow;
}

class BackupSeedPage extends ConsumerStatefulWidget {
  const BackupSeedPage({
    super.key,
    this.requireReauth = true,
    this.isOnboardingFlow = false,
  });

  final bool requireReauth;
  final bool isOnboardingFlow;

  @override
  ConsumerState<BackupSeedPage> createState() => _BackupSeedPageState();
}

class _BackupSeedPageState extends ConsumerState<BackupSeedPage> {
  late bool _isAuthorized;

  @override
  void initState() {
    super.initState();
    _isAuthorized = !widget.requireReauth;
    if (widget.requireReauth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateToView();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final phraseAsync = ref.watch(recoveryPhraseProvider);
    final onboarding = ref.watch(onboardingControllerProvider);

    return AppScaffold(
      title: 'Backup Seed',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store this recovery phrase offline. Never share it online.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const InfoBanner(
              type: InfoBannerType.warning,
              message:
                  'Never share this phrase with anyone. Anyone with these words can spend your funds.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isAuthorized)
              phraseAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const InfoBanner(
                  type: InfoBannerType.error,
                  message:
                      'Could not load recovery phrase. Create or restore a wallet first.',
                ),
                data: (phrase) => CopyRow(value: phrase, label: 'Recovery phrase'),
              )
            else
              const InfoBanner(
                type: InfoBannerType.warning,
                message:
                    'Re-authenticate to view your recovery phrase.',
              ),
            if (!_isAuthorized) ...[
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Unlock to view',
                onPressed: _authenticateToView,
              ),
            ],
            if (onboarding.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              InfoBanner(
                type: InfoBannerType.error,
                message: onboarding.errorMessage!,
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: 'I wrote it down',
              onPressed: !_isAuthorized
                  ? null
                  : () async {
                      await ref
                          .read(onboardingControllerProvider.notifier)
                          .prepareSeedChallenge();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushNamed(AppRoutes.confirmSeed);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _authenticateToView() async {
    final security = ref.read(lockControllerProvider).valueOrNull;
    final controller = ref.read(lockControllerProvider.notifier);

    if (!widget.requireReauth) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAuthorized = true;
      });
      return;
    }

    if (security == null || !security.isLockEnabled) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAuthorized = true;
      });
      return;
    }

    bool ok = await controller.requireReauth();
    if (!ok && security.hasPin) {
      if (!mounted) {
        return;
      }
      final pin = await _promptPin(context);
      if (pin != null) {
        ok = await controller.verifyPin(pin);
      }
    }

    if (!ok) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required to reveal seed.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isAuthorized = true;
    });
  }

  Future<String?> _promptPin(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter PIN'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (pin.length != 6) {
                  return;
                }
                Navigator.of(context).pop(pin);
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value;
  }
}
