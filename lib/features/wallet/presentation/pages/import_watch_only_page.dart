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
import 'package:root_wallet/features/wallet/data/services/add_wallet_service.dart';
import 'package:root_wallet/features/wallet/data/services/descriptor_validator.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class ImportWatchOnlyPage extends ConsumerStatefulWidget {
  const ImportWatchOnlyPage({super.key});

  @override
  ConsumerState<ImportWatchOnlyPage> createState() =>
      _ImportWatchOnlyPageState();
}

class _ImportWatchOnlyPageState extends ConsumerState<ImportWatchOnlyPage> {
  final _externalController = TextEditingController();
  final _internalController = TextEditingController();
  bool _showInternal = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _externalController.dispose();
    _internalController.dispose();
    super.dispose();
  }

  Future<void> _pasteTo(TextEditingController controller) async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      controller.text = data.text!.trim();
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _handleImport() async {
    final ext = _externalController.text.trim();
    final internal = _internalController.text.trim();

    if (ext.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a public descriptor or extended public key.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final addWalletService = await ref.read(addWalletServiceProvider.future);
      await addWalletService.importWatchOnlyWallet(
        externalDescriptor: ext,
        internalDescriptor: internal.isEmpty ? null : internal,
      );

      ref.invalidate(walletCapabilityProvider);
      ref.invalidate(walletHomeControllerProvider);
      await ref.read(walletsListProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watch-only wallet imported successfully.')),
      );

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.walletHome,
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is DescriptorValidationException
            ? e.message
            : e is AddWalletDuplicateException
                ? e.message
                : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final cardBg = isDark ? RootBrandColors.nightPine : Colors.white;
    final border = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);

    return AppScaffold(
      title: 'Watch-Only Import',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing + RootSpacing.xl,
        ),
        children: [
          // 1. Hero explanation card
          Container(
            padding: const EdgeInsets.all(RootSpacing.lg),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(RootRadius.lg),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: RootBrandColors.pineGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(RootRadius.xs),
                        border: Border.all(
                          color: RootBrandColors.pineGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'WATCH ONLY',
                        style: TextStyle(
                          color: RootBrandColors.pineGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RootSpacing.md),
                Text(
                  'Monitor funds & create proposals',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This wallet can monitor funds and create unsigned transactions (PSBTs), but it cannot sign or spend Bitcoin on this device.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RootSpacing.md),

          // Security warning banner
          const InfoBanner(
            type: InfoBannerType.info,
            message:
                'Never enter private keys (xprv/tprv). Only public descriptors or tpub are accepted. Testnet only.',
          ),
          const SizedBox(height: RootSpacing.lg),

          // Error display if validation fails
          if (_errorMessage != null) ...[
            InfoBanner(
              type: InfoBannerType.warning,
              message: _errorMessage!,
            ),
            const SizedBox(height: RootSpacing.md),
          ],

          // 2. External Descriptor Input
          Text(
            'Public Descriptor or tpub',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste your external public descriptor (e.g. wpkh(tpub.../0/*)) or raw testnet tpub.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Convenience Import Assumption: Raw tpub imports automatically assume standard BIP-84 '
            '(Native SegWit) with /0/* for external and /1/* for internal change derivation. '
            'For other script types or derivation levels, supply full explicit descriptors.',
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.8),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: RootSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? RootBrandColors.slatePine
                  : const Color(0xFFF4F7F5),
              borderRadius: BorderRadius.circular(RootRadius.md),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.all(RootSpacing.sm),
            child: Column(
              children: [
                TextField(
                  controller: _externalController,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'wpkh([0f056943/84\'/1\'/0\']tpub.../0/*) or tpub...',
                    hintStyle: TextStyle(
                      color: textSecondary.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: RootSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MagneticPressable(
                      onTap: () => _pasteTo(_externalController),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? RootBrandColors.nightPine
                              : Colors.white,
                          borderRadius: BorderRadius.circular(RootRadius.xs),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.paste_rounded, size: 14, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Paste',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: RootSpacing.md),

          // 3. Optional Internal (Change) Descriptor Toggle
          MagneticPressable(
            onTap: () {
              setState(() => _showInternal = !_showInternal);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showInternal
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: RootBrandColors.pineGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Optional: Change Descriptor',
                    style: TextStyle(
                      color: RootBrandColors.pineGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showInternal) ...[
            const SizedBox(height: RootSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? RootBrandColors.slatePine
                    : const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(RootRadius.md),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.all(RootSpacing.sm),
              child: Column(
                children: [
                  TextField(
                    controller: _internalController,
                    maxLines: 4,
                    minLines: 2,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'wpkh([0f056943/84\'/1\'/0\']tpub.../1/*)',
                      hintStyle: TextStyle(
                        color: textSecondary.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: RootSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MagneticPressable(
                        onTap: () => _pasteTo(_internalController),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? RootBrandColors.nightPine
                                : Colors.white,
                            borderRadius: BorderRadius.circular(RootRadius.xs),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.paste_rounded, size: 14, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Paste',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: RootSpacing.xl),

          // 4. Import action button
          PrimaryButton(
            label: _isLoading ? 'Validating descriptor...' : 'Import watch-only wallet',
            onPressed: _isLoading ? null : _handleImport,
          ),
        ],
      ),
    );
  }
}
