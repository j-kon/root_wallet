import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/send/presentation/models/send_draft.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Root Wallet brand Fee Selector with Liquid Sliding Indicator.
/// Adheres strictly to solid brand surfaces, clear typography, and responsive
/// 3-tier fee selection with liquid stretch physics.
class FeeSelector extends ConsumerStatefulWidget {
  const FeeSelector({super.key});

  @override
  ConsumerState<FeeSelector> createState() => _FeeSelectorState();
}

class _FeeSelectorState extends ConsumerState<FeeSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _toIndex = 1;
  double _startFractionalCenter = 1.5;

  @override
  void initState() {
    super.initState();
    final initialPreset = ref.read(sendControllerProvider).draft.feePreset;
    final initialIndex = FeePreset.values.indexOf(initialPreset).clamp(0, 2);
    _toIndex = initialIndex;
    _startFractionalCenter = initialIndex + 0.5;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _computeCurrentFractionalCenter() {
    if (!_controller.isAnimating) {
      return _toIndex + 0.5;
    }
    final t = _controller.value;
    final tCenter = Curves.easeInOutCubic.transform(t);
    final targetCenter = _toIndex + 0.5;
    return lerpDouble(_startFractionalCenter, targetCenter, tCenter) ??
        targetCenter;
  }

  void _onSelectPreset(FeePreset preset, int suggestedRate) {
    final newIndex = FeePreset.values.indexOf(preset).clamp(0, 2);
    if (newIndex == _toIndex && !_controller.isAnimating) {
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(sendControllerProvider.notifier).setFeePreset(preset, suggestedRate);

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      setState(() {
        _toIndex = newIndex;
        _startFractionalCenter = newIndex + 0.5;
      });
      _controller.value = 1.0;
      return;
    }

    setState(() {
      _startFractionalCenter = _computeCurrentFractionalCenter();
      _toIndex = newIndex;
    });

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendControllerProvider);
    final suggested = ref.watch(suggestedFeeProvider);
    final isCompact = context.isCompactWidth;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentPresetIndex =
        FeePreset.values.indexOf(state.draft.feePreset).clamp(0, 2);
    if (currentPresetIndex != _toIndex && !_controller.isAnimating) {
      _toIndex = currentPresetIndex;
      _startFractionalCenter = currentPresetIndex + 0.5;
    }

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

    final trackBg =
        isDark ? RootBrandColors.slatePine : const Color(0xFFF4F7F5);
    final trackBorder =
        isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC);
    final pillBg =
        isDark ? const Color(0xFF16382C) : const Color(0xFFE8F3EE);
    const pillBorder = RootBrandColors.pineGreen;

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

        // Sliding Liquid Fee Priority Selector Track
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(RootRadius.pill),
            border: Border.all(color: trackBorder, width: 1.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final slotWidth = totalWidth / 3;
              const indicatorHMargin = 3.0;
              const indicatorVMargin = 3.0;
              final pillHeight = 46.0 - (indicatorVMargin * 2);

              return Stack(
                children: [
                  // Liquid Pill Selection Indicator
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      final targetCenter = _toIndex + 0.5;
                      final distance =
                          (_toIndex + 0.5 - _startFractionalCenter).abs();
                      final direction =
                          (_toIndex + 0.5 >= _startFractionalCenter)
                              ? 1.0
                              : -1.0;

                      final tCenter = Curves.easeInOutCubic.transform(t);
                      final currentCenter = lerpDouble(
                            _startFractionalCenter,
                            targetCenter,
                            tCenter,
                          ) ??
                          targetCenter;

                      // Liquid horizontal stretch scaled by distance
                      final maxStretchFraction =
                          0.14 + 0.05 * distance.clamp(1.0, 2.0);
                      final stretch = maxStretchFraction * sin(t * pi);

                      final leadBias = cos(t * pi);
                      final leadShare = 0.5 + 0.35 * leadBias * direction;
                      final trailShare = 1.0 - leadShare;

                      final rightOffset = 0.5 +
                          stretch *
                              (direction > 0 ? leadShare : trailShare);
                      final leftOffset = -0.5 -
                          stretch *
                              (direction > 0 ? trailShare : leadShare);

                      final fractionalLeft = currentCenter + leftOffset;
                      final fractionalRight = currentCenter + rightOffset;

                      final pillLeft =
                          (fractionalLeft * slotWidth + indicatorHMargin)
                              .clamp(
                                indicatorHMargin,
                                totalWidth - indicatorHMargin - 20.0,
                              );
                      final pillRight =
                          (fractionalRight * slotWidth - indicatorHMargin)
                              .clamp(
                                indicatorHMargin + 20.0,
                                totalWidth - indicatorHMargin,
                              );
                      final pillWidth =
                          (pillRight - pillLeft).clamp(20.0, totalWidth);

                      return Positioned(
                        left: pillLeft,
                        top: indicatorVMargin,
                        width: pillWidth,
                        height: pillHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius:
                                BorderRadius.circular(RootRadius.pill),
                            border: Border.all(color: pillBorder, width: 1.5),
                          ),
                        ),
                      );
                    },
                  ),

                  // Interactive Preset Options
                  Row(
                    children: [
                      for (int i = 0; i < FeePreset.values.length; i++) ...[
                        Expanded(
                          child: _LiquidPresetSlot(
                            preset: FeePreset.values[i],
                            isSelected: i == _toIndex,
                            compact: isCompact || constraints.maxWidth < 320,
                            isDark: isDark,
                            onTap: () => _onSelectPreset(
                              FeePreset.values[i],
                              suggestedRate,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: RootSpacing.sm),

        // Animated Fee Metrics Details Box
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          child: Container(
            key: ValueKey(state.draft.feePreset),
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
        ),
      ],
    );
  }
}

class _LiquidPresetSlot extends StatelessWidget {
  const _LiquidPresetSlot({
    required this.preset,
    required this.isSelected,
    required this.compact,
    required this.isDark,
    required this.onTap,
  });

  final FeePreset preset;
  final bool isSelected;
  final bool compact;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? (isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine)
        : (isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68));
    final iconColor = isSelected
        ? RootBrandColors.pineGreen
        : (isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68));

    return MagneticPressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 46,
        width: double.infinity,
        color: Colors.transparent,
        alignment: Alignment.center,
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
