import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/features/transactions/presentation/widgets/transaction_filter_bar.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';

class TransactionSummary extends StatelessWidget {
  const TransactionSummary({
    super.key,
    required this.items,
    required this.filter,
    this.obscureAmounts = false,
  });

  final List<TxItem> items;
  final TransactionFilter filter;
  final bool obscureAmounts;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    final count = items.length;
    final countLabel = count == 1 ? '1 transaction' : '$count transactions';

    var totalSats = 0;
    for (final item in items) {
      if (item.isIncoming) {
        totalSats += item.amountSats;
      } else {
        totalSats -= item.amountSats;
      }
    }

    final totalDisplay = obscureAmounts
        ? AppFormatters.obscuredSats()
        : (totalSats >= 0
              ? '+${AppFormatters.sats(totalSats)}'
              : '-${AppFormatters.sats(totalSats.abs())}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RootSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            countLabel,
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          if (items.isNotEmpty && filter != TransactionFilter.all)
            Text(
              'Net: $totalDisplay',
              style: TextStyle(
                color: totalSats >= 0
                    ? RootBrandColors.pineGreen
                    : RootBrandColors.amberAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
