import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/send/presentation/widgets/fee_selector.dart';

class SendPage extends ConsumerWidget {
  const SendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendFormProvider);
    final notifier = ref.read(sendFormProvider.notifier);

    return AppScaffold(
      title: 'Send',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Destination address',
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.setAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Amount (sats)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: notifier.setAmount,
            ),
            const SizedBox(height: 12),
            const FeeSelector(),
            const SizedBox(height: 12),
            if (state.errorMessage != null)
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Spacer(),
            PrimaryButton(
              label: state.isSubmitting ? 'Building...' : 'Continue',
              onPressed: state.isSubmitting
                  ? null
                  : () async {
                      final ok = await notifier.buildTransaction();
                      if (ok && context.mounted) {
                        Navigator.of(context).pushNamed(AppRoutes.confirmSend);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
