import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';

class FeeSelector extends ConsumerWidget {
  const FeeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(sendFormProvider);
    final notifier = ref.read(sendFormProvider.notifier);
    final suggested = ref.watch(suggestedFeeProvider);

    final options = <int>{1, 2, 5, 10, 20, form.feeRate.satsPerVByte};
    if (suggested.hasValue) {
      options.add(suggested.value!.satsPerVByte);
    }

    final sorted = options.toList()..sort();

    return DropdownButtonFormField<int>(
      initialValue: form.feeRate.satsPerVByte,
      decoration: const InputDecoration(
        labelText: 'Fee rate (sat/vB)',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final value in sorted)
          DropdownMenuItem<int>(value: value, child: Text('$value sat/vB')),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        notifier.setFeeRate(FeeRate(satsPerVByte: value));
      },
    );
  }
}
