import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

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
      title: 'Back up phrase',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          AppSpacing.sm,
        ),
        child: ListView(
          children: [
            GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              tint: AppColors.glassSurfaceStrongOf(
                context,
              ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.95),
              highlightOpacity: 0.05,
              padding: EdgeInsets.all(
                context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -34,
                    right: -20,
                    child: _BackupOrb(
                      size: 136,
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -34,
                    child: _BackupOrb(
                      size: 108,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BackupBadge(
                        icon: Icons.shield_outlined,
                        label: 'Recovery backup',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Store this recovery phrase offline. Never share it online.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'These words are the master key to your wallet. Back them up before you continue.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
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
                data: (phrase) => _SeedPhraseCard(
                  phrase: phrase,
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: phrase));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recovery phrase copied.')),
                    );
                  },
                ),
              )
            else
              const InfoBanner(
                type: InfoBannerType.warning,
                message: 'Re-authenticate to view your recovery phrase.',
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
            const SizedBox(height: AppSpacing.lg),
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
            SizedBox(height: context.navBarBottomSpacing),
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
    return showPinEntryDialog(
      context,
      title: 'Enter PIN',
      subtitle: 'Verify your PIN before revealing the recovery phrase.',
      confirmLabel: 'Verify',
    );
  }
}

class _SeedPhraseCard extends StatelessWidget {
  const _SeedPhraseCard({required this.phrase, required this.onCopy});

  final String phrase;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final words = phrase
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
      highlightOpacity: 0.05,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recovery phrase',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Write these words down in order and keep them offline.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < words.length; i++)
                _SeedWordChip(index: i + 1, word: words[i]),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeedWordChip extends StatelessWidget {
  const _SeedWordChip({required this.index, required this.word});

  final int index;
  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaisedOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$index.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            word,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BackupBadge extends StatelessWidget {
  const _BackupBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 224.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        tint: AppColors.glassSurfaceOf(
          context,
        ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.88),
        borderColor: AppColors.glassBorderOf(context).withValues(alpha: 0.72),
        shadowColor: Colors.transparent,
        highlightOpacity: 0.03,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryOf(context)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: context.isVeryCompactWidth ? 11.5 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupOrb extends StatelessWidget {
  const _BackupOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
