import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
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
    final tone = isSelected
        ? AppColors.primaryOf(context)
        : AppColors.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOf(context).withValues(alpha: 0.12)
                : AppColors.glassSurfaceOf(
                    context,
                  ).withValues(alpha: AppColors.isDark(context) ? 0.34 : 0.68),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryOf(context).withValues(alpha: 0.50)
                  : AppColors.glassBorderOf(context).withValues(alpha: 0.62),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  type.shortLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      type.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: tone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
