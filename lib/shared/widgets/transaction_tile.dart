import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.isIncoming,
    required this.isPending,
    this.obscureAmount = false,
    this.onTap,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final bool isIncoming;
  final bool isPending;
  final bool obscureAmount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 390;
    final textSecondary = AppColors.textSecondaryOf(context);
    final statusTextColor = isPending
        ? (AppColors.isDark(context)
              ? const Color(0xFFFFD48B)
              : Colors.brown.shade800)
        : (AppColors.isDark(context)
              ? const Color(0xFF91E2C6)
              : Colors.green.shade900);
    final accent = isIncoming ? AppColors.success : AppColors.warning;
    final icon = isIncoming
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;
    final amountPrefix = isIncoming ? '+' : '-';
    final directionLabel = isIncoming ? 'Received BTC' : 'Sent BTC';
    final statusLabel = isPending ? 'Pending' : 'Confirmed';
    final amountText = Text(
      obscureAmount
          ? AppFormatters.obscuredSats()
          : '$amountPrefix$amountSats sats',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
      ),
      textAlign: isCompact ? TextAlign.left : TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.md),
            tint: AppColors.glassSurfaceOf(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.54 : 0.78),
            borderColor: accent.withValues(alpha: 0.18),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              directionLabel,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(child: amountText),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _compactTxId(txId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(letterSpacing: 0.15),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (isCompact) ...[
                        amountText,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isCompact ? 148 : 220,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    AppDateTime.ymdHm(timestamp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? AppColors.warning.withValues(alpha: 0.14)
                                  : AppColors.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: statusTextColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
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

  String _compactTxId(String value) {
    if (value.length <= 14) {
      return value;
    }

    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }
}
