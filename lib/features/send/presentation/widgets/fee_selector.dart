import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        Text('Fee speed', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
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
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${state.draft.feeRate.satsPerVByte} sat/vB estimated',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
