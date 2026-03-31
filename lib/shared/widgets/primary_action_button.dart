import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

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
    final accent = accentColor ?? AppColors.primary;
    final isCompact = context.isCompactWidth;
    final textSecondary = AppColors.textSecondaryOf(context);
    final iconSize = isCompact ? 42.0 : 46.0;
    final height = isCompact ? 124.0 : 132.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.md),
            tint: AppColors.glassSurfaceOf(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.88),
            borderColor: accent.withValues(alpha: 0.14),
            shadowColor: accent.withValues(alpha: 0.06),
            highlightOpacity: 0.07,
            child: Stack(
              children: [
                Positioned(
                  top: -18,
                  right: -10,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.16),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(
                    isCompact ? AppSpacing.sm : AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: accent,
                              size: isCompact ? 22 : 24,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: isCompact ? 28 : 30,
                            height: isCompact ? 28 : 30,
                            decoration: BoxDecoration(
                              color: AppColors.glassHighlightOf(
                                context,
                              ).withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              size: isCompact ? 15 : 16,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
