import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surfaceMuted = AppColors.surfaceMutedOf(context);
    final border = AppColors.borderOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: border),
              ),
              child: Icon(icon, color: textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
