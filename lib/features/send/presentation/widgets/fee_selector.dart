import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/features/send/presentation/models/send_draft.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';

class FeeSelector extends ConsumerWidget {
  const FeeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendControllerProvider);
    final notifier = ref.read(sendControllerProvider.notifier);
    final suggested = ref.watch(suggestedFeeProvider);

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
        SegmentedButton<FeePreset>(
          segments: const [
            ButtonSegment<FeePreset>(
              value: FeePreset.slow,
              label: Text('Slow'),
              icon: Icon(Icons.hourglass_bottom_rounded),
            ),
            ButtonSegment<FeePreset>(
              value: FeePreset.standard,
              label: Text('Standard'),
              icon: Icon(Icons.timelapse_rounded),
            ),
            ButtonSegment<FeePreset>(
              value: FeePreset.fast,
              label: Text('Fast'),
              icon: Icon(Icons.bolt_rounded),
            ),
          ],
          selected: <FeePreset>{state.draft.feePreset},
          onSelectionChanged: (selectedSet) {
            final selected = selectedSet.first;
            notifier.setFeePreset(selected, suggestedRate);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
