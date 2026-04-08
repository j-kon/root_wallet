import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';

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
    final palette = _palette(context, type);

    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.md),
      tint: palette.$1,
      borderColor: palette.$2.withValues(alpha: 0.18),
      shadowColor: palette.$2.withValues(alpha: 0.05),
      highlightOpacity: 0.06,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.$2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon ?? palette.$3, color: palette.$2, size: 18),
          ),
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

  (Color, Color, IconData) _palette(BuildContext context, InfoBannerType type) {
    final isDark = AppColors.isDark(context);

    switch (type) {
      case InfoBannerType.info:
        return (
          isDark ? const Color(0xFF123A31) : const Color(0xFFE8F6F1),
          isDark ? const Color(0xFFAEECD7) : const Color(0xFF0F614B),
          Icons.info_outline_rounded,
        );
      case InfoBannerType.warning:
        return (
          isDark ? const Color(0xFF412B08) : const Color(0xFFFFF2DB),
          isDark ? const Color(0xFFFFD48B) : const Color(0xFF8A5306),
          Icons.warning_amber_rounded,
        );
      case InfoBannerType.success:
        return (
          isDark ? const Color(0xFF11352B) : const Color(0xFFE8F7F0),
          isDark ? const Color(0xFFADF0D6) : const Color(0xFF12644D),
          Icons.check_circle_outline_rounded,
        );
      case InfoBannerType.error:
        return (
          isDark ? const Color(0xFF432020) : const Color(0xFFFFEDEC),
          isDark ? const Color(0xFFFFC1C1) : const Color(0xFFAE3434),
          Icons.error_outline_rounded,
        );
    }
  }
}
