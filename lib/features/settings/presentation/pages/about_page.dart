import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(appEnvProvider);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'About',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        children: [
          // 1. Solid Product Showcase Hero Card
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
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: RootBrandColors.pineGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: RootBrandColors.pineGreen.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 26,
                        color: RootBrandColors.pineGreen,
                      ),
                    ),
                    const SizedBox(width: RootSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: TextStyle(
                              color: isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pure self-custody Bitcoin infrastructure',
                            style: TextStyle(
                              color: RootBrandColors.pineGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RootSpacing.md),
                Text(
                  'A self-custody Flutter wallet focused on clarity, trust, and secure local control.',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
                Wrap(
                  spacing: RootSpacing.xs,
                  runSpacing: RootSpacing.xs,
                  children: [
                    _AboutPill(
                      icon: Icons.layers_outlined,
                      label: 'Feature-first architecture',
                    ),
                    _AboutPill(
                      icon: Icons.hub_outlined,
                      label: 'Riverpod state management',
                    ),
                    _AboutPill(
                      icon: Icons.language_rounded,
                      label: env.isProduction
                          ? 'Production flavor'
                          : 'Development flavor',
                    ),
                    _AboutPill(
                      icon: Icons.tag_rounded,
                      label:
                          'Version ${AppConstants.appVersionName}+${AppConstants.appBuildNumber}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: RootSpacing.md),

          // 2. Design Principles Panel
          const _AboutPanel(
            title: 'Design principles',
            subtitle: 'How the product should behave as it grows.',
            bulletPoints: [
              'Trust first: show network, sync health, and backup posture clearly.',
              'Reduce user doubt: important actions should explain risk before execution.',
              'Keep architecture readable: features, domain logic, and UI state remain separated.',
            ],
          ),

          const SizedBox(height: RootSpacing.md),

          // 3. Technical Posture Panel
          const _AboutPanel(
            title: 'Technical posture',
            subtitle: 'Current implementation direction.',
            bulletPoints: [
              'Local credentials and security controls are handled on-device.',
              'Wallet flows are structured into feature modules and use cases.',
              'The app is currently optimized around Bitcoin testnet workflows.',
            ],
          ),

          const SizedBox(height: RootSpacing.md),

          // 4. Support Panel
          Container(
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
                  'Support',
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
                  'Open GitHub support or copy the link for later.',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
                if (context.isCompactWidth) ...[
                  MagneticPressable(
                    onTap: () => _copySupport(context),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? RootBrandColors.slatePine
                            : const Color(0xFFE8EFEA),
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: isDark
                                ? RootBrandColors.warmIvory
                                : RootBrandColors.charcoalPine,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Copy support link',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RootSpacing.sm),
                  MagneticPressable(
                    onTap: () => _openSupport(context, ref),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: RootBrandColors.pineGreen,
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: RootBrandColors.pineGreen,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: RootBrandColors.pureWhite,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Open support',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: RootBrandColors.pureWhite,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: MagneticPressable(
                          onTap: () => _copySupport(context),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? RootBrandColors.slatePine
                                  : const Color(0xFFE8EFEA),
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              border: Border.all(
                                color: isDark
                                    ? RootBrandColors.borderPine
                                    : const Color(0xFFD7E3DC),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: isDark
                                      ? RootBrandColors.warmIvory
                                      : RootBrandColors.charcoalPine,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Copy support link',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark
                                          ? RootBrandColors.warmIvory
                                          : RootBrandColors.charcoalPine,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: RootSpacing.sm),
                      Expanded(
                        child: MagneticPressable(
                          onTap: () => _openSupport(context, ref),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: RootBrandColors.pineGreen,
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              border: Border.all(
                                color: RootBrandColors.pineGreen,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: RootBrandColors.pureWhite,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Open support',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: RootBrandColors.pureWhite,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copySupport(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(const ClipboardData(text: AppConstants.supportUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support link copied.')));
  }

  Future<void> _openSupport(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(AppConstants.supportUrl);
    final launched = await ref
        .read(urlLauncherServiceProvider)
        .openExternalUrl(uri);
    if (launched || !context.mounted) return;
    await _copySupport(context);
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({
    required this.title,
    required this.subtitle,
    required this.bulletPoints,
  });

  final String title;
  final String subtitle;
  final List<String> bulletPoints;

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
            title,
            style: TextStyle(
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          for (final point in bulletPoints) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: RootBrandColors.pineGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: RootSpacing.sm),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      color: isDark
                          ? RootBrandColors.warmIvory
                          : RootBrandColors.charcoalPine,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (point != bulletPoints.last)
              const SizedBox(height: RootSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AboutPill extends StatelessWidget {
  const _AboutPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
            ? 224.0
            : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
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
            Icon(icon, size: 13, color: RootBrandColors.pineGreen),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? RootBrandColors.warmIvory
                      : RootBrandColors.charcoalPine,
                  fontSize: context.isVeryCompactWidth ? 11.0 : 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
