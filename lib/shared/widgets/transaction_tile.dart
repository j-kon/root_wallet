import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/date_time.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.isIncoming,
    required this.isPending,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final bool isIncoming;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final icon = isIncoming
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;
    final amountPrefix = isIncoming ? '+' : '-';
    final statusLabel = isPending ? 'Pending' : 'Confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isIncoming
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            color: isIncoming ? AppColors.success : AppColors.warning,
            size: 18,
          ),
        ),
        title: Text(
          txId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppDateTime.ymdHm(timestamp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.warning.withValues(alpha: 0.16)
                      : AppColors.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isPending
                        ? Colors.brown.shade800
                        : Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          '$amountPrefix$amountSats sats',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: isIncoming ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
