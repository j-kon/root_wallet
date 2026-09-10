import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page_args.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/script_type_option.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class RestoreWalletPage extends ConsumerStatefulWidget {
  const RestoreWalletPage({super.key});

  @override
  ConsumerState<RestoreWalletPage> createState() => _RestoreWalletPageState();
}

class _RestoreWalletPageState extends ConsumerState<RestoreWalletPage> {
  final _controller = TextEditingController();
  WalletScriptType _scriptType = WalletScriptType.nativeSegwit;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateWordCount);
  }

  void _updateWordCount() {
    final words = _controller.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length != _wordCount) {
      setState(() => _wordCount = words.length);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateWordCount);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final sanitized = data.text!.trim().replaceAll(RegExp(r'\s+'), ' ');
      _controller.text = sanitized;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnboardingState>(onboardingControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message == previous?.errorMessage) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.split('\n').first)));
    });

    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Restore wallet',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          RootSpacing.sm,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // 1. Solid Recovery Vault Hero Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? RootBrandColors.nightPine
                          : RootBrandColors.pureWhite,
                      borderRadius: BorderRadius.circular(RootRadius.lg),
                      border: Border.all(
                        color: isDark
                            ? RootBrandColors.borderPine
                            : const Color(0xFFD7E3DC),
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
                                color: RootBrandColors.pineGreen
                                    .withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(RootRadius.md),
                                border: Border.all(
                                  color: RootBrandColors.pineGreen
                                      .withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.restore_rounded,
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
                                    'Recovery flow',
                                    style: TextStyle(
                                      color: RootBrandColors.pineGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Restore an existing wallet with a careful import flow.',
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
                                    'Paste your recovery phrase exactly as written. This app will validate it locally before resuming wallet access.',
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
                      ],
                    ),
                  ),

                  const SizedBox(height: RootSpacing.md),

                  // 2. Recovery Phrase Input Panel
                  _RestorePanel(
                    title: 'Recovery phrase',
                    subtitle:
                        'Use spaces between words and keep the original word order.',
                    headerTrailing: MagneticPressable(
                      onTap: _pasteFromClipboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? RootBrandColors.slatePine
                              : const Color(0xFFE8EFEA),
                          borderRadius: BorderRadius.circular(RootRadius.sm),
                          border: Border.all(
                            color: isDark
                                ? RootBrandColors.borderPine
                                : const Color(0xFFD7E3DC),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.paste_rounded,
                              size: 13,
                              color: isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Paste',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _controller,
                          minLines: 4,
                          maxLines: 6,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            color: isDark
                                ? RootBrandColors.warmIvory
                                : RootBrandColors.charcoalPine,
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Recovery phrase',
                            hintText: 'abandon ability able about above ...',
                            filled: true,
                            fillColor: isDark
                                ? RootBrandColors.slatePine
                                : const Color(0xFFF6F8F7),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              borderSide: BorderSide(
                                color: isDark
                                    ? RootBrandColors.borderPine
                                    : const Color(0xFFD7E3DC),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              borderSide: BorderSide(
                                color: isDark
                                    ? RootBrandColors.borderPine
                                    : const Color(0xFFD7E3DC),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              borderSide: const BorderSide(
                                color: RootBrandColors.pineGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (_wordCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (_wordCount == 12 || _wordCount == 24)
                                      ? RootBrandColors.pineGreen
                                          .withValues(alpha: 0.14)
                                      : RootBrandColors.amberAccent
                                          .withValues(alpha: 0.14),
                                  borderRadius:
                                      BorderRadius.circular(RootRadius.pill),
                                  border: Border.all(
                                    color: (_wordCount == 12 || _wordCount == 24)
                                        ? RootBrandColors.pineGreen
                                            .withValues(alpha: 0.35)
                                        : RootBrandColors.amberAccent
                                            .withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  '$_wordCount words entered',
                                  style: TextStyle(
                                    color: (_wordCount == 12 || _wordCount == 24)
                                        ? RootBrandColors.pineGreen
                                        : RootBrandColors.amberAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: RootSpacing.md),

                  // 3. Address Type Selection Panel
                  _RestorePanel(
                    title: 'Address type',
                    subtitle:
                        'Pick the address family your original wallet used. If unsure, start with Native SegWit.',
                    child: Column(
                      children: WalletScriptType.values
                          .map(
                            (type) => ScriptTypeOption(
                              type: type,
                              isSelected: _scriptType == type,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _scriptType = type);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: RootSpacing.sm),

                  const InfoBanner(
                    type: InfoBannerType.warning,
                    message:
                        'Only restore a phrase you trust and never share it with anyone. The phrase controls wallet access.',
                  ),

                  const SizedBox(height: RootSpacing.sm),

                  const InfoBanner(
                    type: InfoBannerType.info,
                    message:
                        'Root Wallet restores Bitcoin testnet wallets. A mainnet seed can import, but mainnet funds will not appear here.',
                    icon: Icons.info_outline_rounded,
                  ),

                  if (state.errorMessage != null) ...[
                    const SizedBox(height: RootSpacing.md),
                    InfoBanner(
                      type: InfoBannerType.error,
                      message: state.errorMessage!,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: RootSpacing.md),

            MagneticPressable(
              onTap: state.isBusy
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      final phrase = _controller.text.trim();
                      if (phrase.isEmpty) return;

                      final restored = await controller.restoreWallet(
                        phrase,
                        scriptType: _scriptType,
                      );
                      if (!context.mounted) return;
                      if (!restored) return;

                      final recoveryPhrase = ref
                          .read(onboardingControllerProvider)
                          .recoveryPhrase;

                      Navigator.of(context).pushReplacementNamed(
                        AppRoutes.backupSeed,
                        arguments: BackupSeedPageArgs(
                          requireReauth: false,
                          isOnboardingFlow: true,
                          recoveryPhrase: recoveryPhrase,
                        ),
                      );
                    },
              child: PrimaryButton(
                label: state.isBusy ? 'Restoring...' : 'Restore wallet',
                onPressed: state.isBusy
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        final phrase = _controller.text.trim();
                        if (phrase.isEmpty) return;

                        final restored = await controller.restoreWallet(
                          phrase,
                          scriptType: _scriptType,
                        );
                        if (!context.mounted) return;
                        if (!restored) return;

                        final recoveryPhrase = ref
                            .read(onboardingControllerProvider)
                            .recoveryPhrase;

                        Navigator.of(context).pushReplacementNamed(
                          AppRoutes.backupSeed,
                          arguments: BackupSeedPageArgs(
                            requireReauth: false,
                            isOnboardingFlow: true,
                            recoveryPhrase: recoveryPhrase,
                          ),
                        );
                      },
              ),
            ),
            SizedBox(height: context.navBarBottomSpacing),
          ],
        ),
      ),
    );
  }
}

class _RestorePanel extends StatelessWidget {
  const _RestorePanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
          const SizedBox(height: RootSpacing.md),
          child,
        ],
      ),
    );
  }
}
