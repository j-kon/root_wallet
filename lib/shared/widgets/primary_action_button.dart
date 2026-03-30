import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
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
    final surface = AppColors.surfaceOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final shadow = AppColors.shadowOf(context);
    final iconSize = isCompact ? 42.0 : 46.0;
    final height = isCompact ? 124.0 : 132.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surface, accent.withValues(alpha: 0.10)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? AppSpacing.sm : AppSpacing.md),
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
                      ),
                      child: Icon(icon, color: accent, size: isCompact ? 22 : 24),
                    ),
                    const Spacer(),
                    Container(
                      width: isCompact ? 28 : 30,
                      height: isCompact ? 28 : 30,
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: 0.74),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
