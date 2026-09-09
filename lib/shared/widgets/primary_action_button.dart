import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? subtitle;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = accentColor ?? RootBrandColors.pineGreen;
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
    final iconBoxBg = isDark
        ? RootBrandColors.deepForest
        : RootBrandColors.warmIvory;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RootRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(RootRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(RootSpacing.md),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(RootRadius.lg),
            border: Border.all(color: border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBoxBg,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                      border: Border.all(color: border, width: 1.0),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: RootSpacing.md),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
