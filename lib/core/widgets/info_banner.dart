import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';

enum InfoBannerType { info, warning, success, error }

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.type = InfoBannerType.info,
    this.icon,
  });

  final String message;
  final InfoBannerType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.$2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? palette.$3, color: palette.$2, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.$2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _palette(InfoBannerType type) {
    switch (type) {
      case InfoBannerType.info:
        return (
          AppColors.primary.withValues(alpha: 0.10),
          AppColors.primary,
          Icons.info_outline_rounded,
        );
      case InfoBannerType.warning:
        return (
          AppColors.warning.withValues(alpha: 0.16),
          Colors.brown.shade800,
          Icons.warning_amber_rounded,
        );
      case InfoBannerType.success:
        return (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
          Icons.check_circle_outline_rounded,
        );
      case InfoBannerType.error:
        return (
          AppColors.danger.withValues(alpha: 0.12),
          AppColors.danger,
          Icons.error_outline_rounded,
        );
    }
  }
}
