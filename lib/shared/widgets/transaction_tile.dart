import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.txId,
    required this.amountSats,
    required this.timestamp,
    required this.isIncoming,
    required this.isPending,
    this.label,
    this.obscureAmount = false,
    this.onTap,
  });

  final String txId;
  final int amountSats;
  final DateTime timestamp;
  final bool isIncoming;
  final bool isPending;
  final String? label;
  final bool obscureAmount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    final accent = isIncoming
        ? RootBrandColors.pineGreen
        : RootBrandColors.amberAccent;
    final icon = isIncoming
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final amountPrefix = isIncoming ? '+' : '-';
    final directionLabel = isIncoming ? 'Received' : 'Sent';
    final statusLabel = isPending ? 'Pending' : 'Confirmed';

    final btcDisplay = obscureAmount
        ? AppFormatters.obscuredBtc()
        : '$amountPrefix${AppFormatters.btcFromSats(amountSats)}';
    final satsDisplay = obscureAmount
        ? AppFormatters.obscuredSats()
        : '$amountPrefix${AppFormatters.sats(amountSats)}';

    return Container(
      margin: const EdgeInsets.only(bottom: RootSpacing.sm),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x0C0E1B18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RootRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(RootSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Direction icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? RootBrandColors.deepForest
                        : RootBrandColors.warmIvory,
                    borderRadius: BorderRadius.circular(RootRadius.md),
                    border: Border.all(
                      color: isDark
                          ? RootBrandColors.borderPine
                          : const Color(0xFFD7E3DC),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: RootSpacing.md),

                // Transaction details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Direction and Primary BTC amount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              directionLabel,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: RootSpacing.xs),
                          Text(
                            btcDisplay,
                            style: TextStyle(
                              color: accent,
                              fontSize: isCompact ? 13 : 14,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Second row: Optional Label or TxId + Secondary Sats amount
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (label != null && label!.trim().isNotEmpty)
                                  ? label!
                                  : _compactTxId(txId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    (label != null && label!.trim().isNotEmpty)
                                    ? textPrimary
                                    : textSecondary,
                                fontSize: 12,
                                fontWeight:
                                    (label != null && label!.trim().isNotEmpty)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: RootSpacing.xs),
                          Text(
                            satsDisplay,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RootSpacing.xs),

                      // Third row: Time & Confirmation pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    AppDateTime.ymdHm(timestamp),
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: RootSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: RootSpacing.xs + 2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (isPending
                                        ? RootBrandColors.amberAccent
                                              .withValues(alpha: 0.16)
                                        : RootBrandColors.pineGreen.withValues(
                                            alpha: 0.16,
                                          ))
                                  : (isPending
                                        ? const Color(0xFFFFF3E0)
                                        : const Color(0xFFE8F6F1)),
                              borderRadius: BorderRadius.circular(
                                RootRadius.pill,
                              ),
                              border: Border.all(
                                color: isDark
                                    ? (isPending
                                          ? RootBrandColors.amberAccent
                                                .withValues(alpha: 0.4)
                                          : RootBrandColors.pineGreen
                                                .withValues(alpha: 0.4))
                                    : (isPending
                                          ? RootBrandColors.amberAccent
                                                .withValues(alpha: 0.3)
                                          : RootBrandColors.pineGreen
                                                .withValues(alpha: 0.3)),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: isPending
                                    ? RootBrandColors.amberAccent
                                    : RootBrandColors.pineGreen,
                                fontSize: 11,
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
