import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';

enum TransactionFilter {
  all('All'),
  received('Received'),
  sent('Sent'),
  pending('Pending');

  const TransactionFilter(this.label);
  final String label;
}

class TransactionFilterBar extends StatelessWidget {
  const TransactionFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final TransactionFilter selectedFilter;
  final ValueChanged<TransactionFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in TransactionFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: RootSpacing.xs),
              child: _FilterChip(
                label: filter.label,
                isSelected: filter == selectedFilter,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFilterChanged(filter);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = RootBrandColors.pineGreen;
    final selectedText = RootBrandColors.charcoalPine;

    final inactiveBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final inactiveBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final inactiveText = isDark
        ? RootBrandColors.warmIvory
        : const Color(0xFF5E6F68);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label filter',
      child: Material(
        color: isSelected ? selectedBg : inactiveBg,
        borderRadius: BorderRadius.circular(RootRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RootRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RootSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RootRadius.pill),
              border: Border.all(
                color: isSelected ? selectedBg : inactiveBorder,
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedText : inactiveText,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
