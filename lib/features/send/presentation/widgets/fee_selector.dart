import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/features/send/presentation/models/send_draft.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Root Wallet brand Fee Selector.
/// Adheres strictly to solid brand surfaces, clear typography, and responsive
/// 3-tier fee selection without text truncation.
class FeeSelector extends ConsumerWidget {
  const FeeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendControllerProvider);
    final notifier = ref.read(sendControllerProvider.notifier);
    final suggested = ref.watch(suggestedFeeProvider);
    final isCompact = context.isCompactWidth;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final suggestedRate = suggested.maybeWhen(
      data: (fee) => fee.satsPerVByte,
      orElse: () => state.draft.feeRate.satsPerVByte,
    );

    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final detailsBg = isDark
        ? RootBrandColors.slatePine
        : const Color(0xFFF7FAF8);
    final detailsBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFE1EBE5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fee priority',
          style: TextStyle(
            color: titleColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Higher fees generally improve confirmation speed.',
          style: TextStyle(color: bodyColor, fontSize: 12.5),
        ),
        const SizedBox(height: RootSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = RootSpacing.sm;
            final itemWidth = (constraints.maxWidth - (gap * 2)) / 3;
            final hideIcons = isCompact || constraints.maxWidth < 320;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final preset in FeePreset.values)
                  SizedBox(
                    width: itemWidth,
                    child: _FeePresetButton(
                      preset: preset,
                      selected: preset == state.draft.feePreset,
                      compact: hideIcons,
                      isDark: isDark,
                      onTap: () => notifier.setFeePreset(preset, suggestedRate),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: RootSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(RootSpacing.md),
          decoration: BoxDecoration(
            color: detailsBg,
            borderRadius: BorderRadius.circular(RootRadius.md),
            border: Border.all(color: detailsBorder, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: RootBrandColors.pineGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${state.draft.feePreset.label} priority',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                state.draft.feePreset.helperText,
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
              const SizedBox(height: RootSpacing.sm),
              Wrap(
                spacing: RootSpacing.sm,
                runSpacing: RootSpacing.sm,
                children: [
                  _FeeMetricChip(
                    icon: Icons.speed_rounded,
                    label: '${state.draft.feeRate.satsPerVByte} sat/vB',
                    isDark: isDark,
                  ),
                  _FeeMetricChip(
                    icon: Icons.schedule_rounded,
                    label: state.draft.feePreset.etaLabel,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeeMetricChip extends StatelessWidget {
  const _FeeMetricChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final chipBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final chipBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RootSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(color: chipBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RootBrandColors.pineGreen),
          const SizedBox(width: RootSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeePresetButton extends StatelessWidget {
  const _FeePresetButton({
    required this.preset,
    required this.selected,
    required this.onTap,
    required this.compact,
    required this.isDark,
  });

  final FeePreset preset;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Color iconColor;

    if (selected) {
      bgColor = isDark ? const Color(0xFF16382C) : const Color(0xFFE8F3EE);
      borderColor = RootBrandColors.pineGreen;
      textColor = isDark
          ? RootBrandColors.warmIvory
          : RootBrandColors.charcoalPine;
      iconColor = RootBrandColors.pineGreen;
    } else {
      bgColor = isDark ? RootBrandColors.slatePine : const Color(0xFFF4F7F5);
      borderColor = isDark
          ? RootBrandColors.borderPine
          : const Color(0xFFD7E3DC);
      textColor = isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68);
      iconColor = isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(RootRadius.pill),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : RootSpacing.sm,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(RootRadius.pill),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                Icon(_iconFor(preset), size: 15, color: iconColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  preset.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: compact ? 12 : 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(FeePreset preset) {
    return switch (preset) {
      FeePreset.slow => Icons.hourglass_bottom_rounded,
      FeePreset.standard => Icons.timelapse_rounded,
      FeePreset.fast => Icons.bolt_rounded,
    };
  }
}
