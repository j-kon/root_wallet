import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/features/send/presentation/models/send_draft.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class FeeSelector extends ConsumerWidget {
  const FeeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendControllerProvider);
    final notifier = ref.read(sendControllerProvider.notifier);
    final suggested = ref.watch(suggestedFeeProvider);
    final isCompact = context.isCompactWidth;

    final suggestedRate = suggested.maybeWhen(
      data: (fee) => fee.satsPerVByte,
      orElse: () => state.draft.feeRate.satsPerVByte,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fee priority',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Higher fees generally improve confirmation speed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = AppSpacing.sm;
            final itemWidth = (constraints.maxWidth - (gap * 2)) / 3;

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
                      compact: isCompact,
                      onTap: () => notifier.setFeePreset(preset, suggestedRate),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.draft.feePreset.label} priority',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.draft.feePreset.helperText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _FeeMetricChip(
                    icon: Icons.speed_rounded,
                    label: '${state.draft.feeRate.satsPerVByte} sat/vB',
                  ),
                  _FeeMetricChip(
                    icon: Icons.schedule_rounded,
                    label: state.draft.feePreset.etaLabel,
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
  const _FeeMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.glassBorderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
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
  });

  final FeePreset preset;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    final border = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.22)
                : AppColors.glassSurfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.accent : border,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconFor(preset),
                size: compact ? 15 : 16,
                color: selected ? primary : textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  preset.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? textPrimary : textSecondary,
                    fontWeight: FontWeight.w700,
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
