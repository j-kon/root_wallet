import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.btcAmount,
    required this.fiatAmountLabel,
    this.subtitle = 'Available portfolio balance',
    this.onTap,
  });

  final String subtitle;
  final String btcAmount;
  final String fiatAmountLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactWidth;
    final isDark = AppColors.isDark(context);

    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final iconBoxBg = isDark
        ? RootBrandColors.deepForest
        : RootBrandColors.warmIvory;
    final chipBg = isDark
        ? RootBrandColors.deepForest
        : RootBrandColors.warmIvory;
    final chipBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final chipText = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RootRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RootRadius.xl),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(RootRadius.xl),
            border: Border.all(color: cardBorder, width: 1.0),
          ),
          padding: EdgeInsets.all(isCompact ? RootSpacing.lg : RootSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBoxBg,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                      border: Border.all(color: cardBorder, width: 1.0),
                    ),
                    child: const Icon(
                      Icons.currency_bitcoin_rounded,
                      color: RootBrandColors.amberAccent,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RootSpacing.sm,
                      vertical: RootSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(RootRadius.pill),
                      border: Border.all(color: chipBorder, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: RootBrandColors.pineGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: RootSpacing.xs),
                        Text(
                          'Self-custody',
                          style: TextStyle(
                            color: chipText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? RootSpacing.md : RootSpacing.lg),
              Text(
                subtitle.toUpperCase(),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: RootSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  btcAmount,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 34 : 40,
                    letterSpacing: -1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: RootSpacing.xs),
              Wrap(
                spacing: RootSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    fiatAmountLabel,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '·  Tap to switch unit',
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RootSpacing.lg),
              Wrap(
                spacing: RootSpacing.sm,
                runSpacing: RootSpacing.sm,
                children: [
                  _BalanceMetaChip(
                    icon: Icons.show_chart_rounded,
                    label: fiatAmountLabel,
                    backgroundColor: chipBg,
                    borderColor: chipBorder,
                    textColor: chipText,
                    iconColor: isDark
                        ? RootBrandColors.warmIvory
                        : RootBrandColors.pineGreen,
                  ),
                  _BalanceMetaChip(
                    icon: Icons.shield_outlined,
                    label: 'Keys on-device',
                    backgroundColor: chipBg,
                    borderColor: chipBorder,
                    textColor: chipText,
                    iconColor: RootBrandColors.pineGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceMetaChip extends StatelessWidget {
  const _BalanceMetaChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 220.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RootSpacing.sm,
          vertical: RootSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(RootRadius.pill),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor ?? textColor, size: 15),
            const SizedBox(width: RootSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: context.isVeryCompactWidth ? 11.5 : 12.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
