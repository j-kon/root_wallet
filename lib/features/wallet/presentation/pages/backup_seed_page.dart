import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/security/screen_protection_service.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

export 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page_args.dart';

final backupSeedRecoveryPhraseProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final phrase = await ref
      .watch(secureStorageProvider)
      .read(key: WalletStorageKeys.mnemonic);
  if (phrase == null || phrase.trim().isEmpty) {
    throw StateError('Recovery phrase is not available.');
  }
  return phrase;
});

class BackupSeedPage extends ConsumerStatefulWidget {
  const BackupSeedPage({
    super.key,
    this.requireReauth = true,
    this.isOnboardingFlow = false,
    this.recoveryPhrase,
  });

  final bool requireReauth;
  final bool isOnboardingFlow;
  final String? recoveryPhrase;

  @override
  ConsumerState<BackupSeedPage> createState() => _BackupSeedPageState();
}

class _BackupSeedPageState extends ConsumerState<BackupSeedPage> {
  late final ScreenProtectionService _screenProtection;
  late bool _isAuthorized;
  bool _storedOffline = false;
  bool _understandsRecoveryRisk = false;
  bool _isCopied = false;
  Timer? _copyTimer;

  bool get _canContinue =>
      _isAuthorized && _storedOffline && _understandsRecoveryRisk;

  @override
  void initState() {
    super.initState();
    _isAuthorized = !widget.requireReauth;
    _screenProtection = ref.read(screenProtectionServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_screenProtection.setProtected(true));
    });
    if (widget.requireReauth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateToView();
      });
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    unawaited(_screenProtection.setProtected(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phraseAsync = widget.recoveryPhrase == null
        ? ref.watch(backupSeedRecoveryPhraseProvider)
        : AsyncData(widget.recoveryPhrase!);
    final onboarding = ref.watch(onboardingControllerProvider);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Back up phrase',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          RootSpacing.sm,
        ),
        child: ListView(
          children: [
            // 1. Solid Master Recovery Key Vault Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                borderRadius: BorderRadius.circular(RootRadius.lg),
                border: Border.all(
                  color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                  width: 1.0,
                ),
              ),
              padding: EdgeInsets.all(
                context.isCompactWidth ? RootSpacing.md : RootSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: RootBrandColors.pineGreen.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(RootRadius.md),
                          border: Border.all(
                            color: RootBrandColors.pineGreen.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 22,
                          color: RootBrandColors.pineGreen,
                        ),
                      ),
                      const SizedBox(width: RootSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recovery backup',
                              style: TextStyle(
                                color: RootBrandColors.pineGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Store this recovery phrase offline. Never share it online.',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'These words are the master key to your wallet. Back them up before you continue.',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.mutedSage
                                    : const Color(0xFF5E6F68),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RootSpacing.md),
                  Wrap(
                    spacing: RootSpacing.xs,
                    runSpacing: RootSpacing.xs,
                    children: [
                      _VaultBadge(
                        icon: Icons.vpn_key_rounded,
                        label: 'Master backup key',
                      ),
                      _VaultBadge(
                        icon: Icons.lock_outline_rounded,
                        label: 'BIP-39 Standard',
                      ),
                      _VaultBadge(
                        icon: Icons.phonelink_erase_rounded,
                        label: 'Offline only',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: RootSpacing.md),

            const InfoBanner(
              type: InfoBannerType.warning,
              message:
                  'Never share this phrase with anyone. Anyone with these words can spend your funds.',
            ),

            const SizedBox(height: RootSpacing.md),

            if (_isAuthorized)
              phraseAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => const InfoBanner(
                  type: InfoBannerType.error,
                  message:
                      'Could not load recovery phrase. Create or restore a wallet first.',
                ),
                data: (phrase) => _SeedPhraseCard(
                  phrase: phrase,
                  isCopied: _isCopied,
                  onCopy: () async {
                    HapticFeedback.lightImpact();
                    await Clipboard.setData(ClipboardData(text: phrase));
                    setState(() => _isCopied = true);
                    _copyTimer?.cancel();
                    _copyTimer = Timer(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _isCopied = false);
                    });
                    if (!context.mounted) return;
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
              const SizedBox(height: RootSpacing.md),
              MagneticPressable(
                onTap: _authenticateToView,
                child: PrimaryButton(
                  label: 'Unlock to view',
                  onPressed: _authenticateToView,
                ),
              ),
            ],

            const SizedBox(height: RootSpacing.md),

            _BackupAcknowledgementCard(
              enabled: _isAuthorized,
              storedOffline: _storedOffline,
              understandsRecoveryRisk: _understandsRecoveryRisk,
              onStoredOfflineChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _storedOffline = value);
              },
              onUnderstandsRecoveryRiskChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _understandsRecoveryRisk = value);
              },
            ),

            if (onboarding.errorMessage != null) ...[
              const SizedBox(height: RootSpacing.md),
              InfoBanner(
                type: InfoBannerType.error,
                message: onboarding.errorMessage!,
              ),
            ],

            const SizedBox(height: RootSpacing.lg),

            MagneticPressable(
              onTap: !_canContinue
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      await ref
                          .read(onboardingControllerProvider.notifier)
                          .prepareSeedChallenge();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamed(AppRoutes.confirmSeed);
                    },
              child: PrimaryButton(
                label: 'I wrote it down',
                onPressed: !_canContinue
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await ref
                            .read(onboardingControllerProvider.notifier)
                            .prepareSeedChallenge();
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamed(AppRoutes.confirmSeed);
                      },
              ),
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
      if (!mounted) return;
      setState(() => _isAuthorized = true);
      return;
    }

    if (security == null || !security.isLockEnabled) {
      if (!mounted) return;
      setState(() => _isAuthorized = true);
      return;
    }

    bool ok = await controller.requireReauth();
    if (!ok && security.hasPin) {
      if (!mounted) return;
      final pin = await _promptPin(context);
      if (pin != null) {
        ok = await controller.verifyPin(pin);
      }
    }

    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required to reveal seed.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isAuthorized = true);
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

// ---------------------------------------------------------------------------
// Solid Monospace Word Grid Card
// ---------------------------------------------------------------------------

class _SeedPhraseCard extends StatefulWidget {
  const _SeedPhraseCard({
    required this.phrase,
    required this.onCopy,
    required this.isCopied,
  });

  final String phrase;
  final VoidCallback onCopy;
  final bool isCopied;

  @override
  State<_SeedPhraseCard> createState() => _SeedPhraseCardState();
}

class _SeedPhraseCardState extends State<_SeedPhraseCard> {
  bool _concealed = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.phrase
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(RootSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recovery phrase',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${words.length}-word recovery phrase. Write these words down in order and keep them offline.',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MagneticPressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _concealed = !_concealed);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? RootBrandColors.slatePine : const Color(0xFFE8EFEA),
                    borderRadius: BorderRadius.circular(RootRadius.sm),
                    border: Border.all(
                      color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    _concealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 16,
                    color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              MagneticPressable(
                onTap: widget.onCopy,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: widget.isCopied
                        ? RootBrandColors.pineGreen
                        : isDark
                            ? RootBrandColors.slatePine
                            : const Color(0xFFE8EFEA),
                    borderRadius: BorderRadius.circular(RootRadius.sm),
                    border: Border.all(
                      color: widget.isCopied
                          ? RootBrandColors.pineGreen
                          : isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isCopied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 14,
                        color: widget.isCopied
                            ? RootBrandColors.pureWhite
                            : isDark
                                ? RootBrandColors.warmIvory
                                : RootBrandColors.charcoalPine,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isCopied ? 'Copied' : 'Copy',
                        style: TextStyle(
                          color: widget.isCopied
                              ? RootBrandColors.pureWhite
                              : isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 340 ? 2 : 3;
              final rows = <Widget>[];
              for (var i = 0; i < words.length; i += crossAxisCount) {
                final chunk = words.sublist(
                  i,
                  (i + crossAxisCount).clamp(0, words.length),
                );
                rows.add(
                  Row(
                    children: [
                      for (var j = 0; j < chunk.length; j++) ...[
                        if (j > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _SeedWordTile(
                            index: i + j + 1,
                            word: chunk[j],
                            concealed: _concealed,
                          ),
                        ),
                      ],
                      for (var k = 0; k < crossAxisCount - chunk.length; k++) ...[
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ],
                  ),
                );
                if (i + crossAxisCount < words.length) {
                  rows.add(const SizedBox(height: 8));
                }
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _SeedWordTile extends StatelessWidget {
  const _SeedWordTile({
    required this.index,
    required this.word,
    required this.concealed,
  });

  final int index;
  final String word;
  final bool concealed;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.slatePine : const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(RootRadius.md),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RootBrandColors.pineGreen.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: RootBrandColors.pineGreen,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              concealed ? '••••••' : word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: concealed ? 1.0 : -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Solid Tactile Acknowledgement Card
// ---------------------------------------------------------------------------

class _BackupAcknowledgementCard extends StatelessWidget {
  const _BackupAcknowledgementCard({
    required this.enabled,
    required this.storedOffline,
    required this.understandsRecoveryRisk,
    required this.onStoredOfflineChanged,
    required this.onUnderstandsRecoveryRiskChanged,
  });

  final bool enabled;
  final bool storedOffline;
  final bool understandsRecoveryRisk;
  final ValueChanged<bool> onStoredOfflineChanged;
  final ValueChanged<bool> onUnderstandsRecoveryRiskChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(RootSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Before you continue',
            style: TextStyle(
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Root Wallet cannot recover this phrase for you. Confirm these two checks after writing it down.',
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          _BackupCheckTile(
            enabled: enabled,
            value: storedOffline,
            label: 'I wrote the phrase down offline.',
            onChanged: onStoredOfflineChanged,
          ),
          const SizedBox(height: 8),
          _BackupCheckTile(
            enabled: enabled,
            value: understandsRecoveryRisk,
            label: 'I understand Root Wallet cannot recover it for me.',
            onChanged: onUnderstandsRecoveryRiskChanged,
          ),
        ],
      ),
    );
  }
}

class _BackupCheckTile extends StatelessWidget {
  const _BackupCheckTile({
    required this.enabled,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: MagneticPressable(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value
                ? (isDark
                    ? RootBrandColors.slatePine
                    : const Color(0xFFEDF5F1))
                : (isDark
                    ? const Color(0xFF142420)
                    : const Color(0xFFF7FAF8)),
            borderRadius: BorderRadius.circular(RootRadius.md),
            border: Border.all(
              color: value
                  ? RootBrandColors.pineGreen
                  : (isDark
                      ? RootBrandColors.borderPine
                      : const Color(0xFFD7E3DC)),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value
                      ? RootBrandColors.pineGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: value
                        ? RootBrandColors.pineGreen
                        : (isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF8B9E95)),
                    width: 1.5,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: RootBrandColors.pureWhite,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.warmIvory
                        : RootBrandColors.charcoalPine,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultBadge extends StatelessWidget {
  const _VaultBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.slatePine : const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: RootBrandColors.pineGreen,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
