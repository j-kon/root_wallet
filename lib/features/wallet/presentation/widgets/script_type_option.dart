import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';

class ScriptTypeOption extends StatelessWidget {
  const ScriptTypeOption({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final WalletScriptType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: RootSpacing.sm),
      child: MagneticPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(RootSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? RootBrandColors.slatePine
                    : const Color(0xFFEDF6F2))
                : (isDark
                    ? RootBrandColors.nightPine
                    : RootBrandColors.pureWhite),
            borderRadius: BorderRadius.circular(RootRadius.md),
            border: Border.all(
              color: isSelected
                  ? RootBrandColors.pineGreen
                  : (isDark
                      ? RootBrandColors.borderPine
                      : const Color(0xFFD7E3DC)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? RootBrandColors.pineGreen.withValues(alpha: 0.16)
                      : (isDark
                          ? const Color(0xFF142420)
                          : const Color(0xFFF0F4F2)),
                  borderRadius: BorderRadius.circular(RootRadius.sm),
                  border: Border.all(
                    color: isSelected
                        ? RootBrandColors.pineGreen.withValues(alpha: 0.4)
                        : (isDark
                            ? RootBrandColors.borderPine
                            : const Color(0xFFD7E3DC)),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  type.shortLabel,
                  style: TextStyle(
                    color: isSelected
                        ? RootBrandColors.pineGreen
                        : (isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: RootSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            type.displayName,
                            style: TextStyle(
                              color: isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (type == WalletScriptType.nativeSegwit) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: RootBrandColors.pineGreen
                                  .withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(RootRadius.pill),
                            ),
                            child: const Text(
                              'Recommended',
                              style: TextStyle(
                                color: RootBrandColors.pineGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type.description,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RootSpacing.sm),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? RootBrandColors.pineGreen
                    : (isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF8B9E95)),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
