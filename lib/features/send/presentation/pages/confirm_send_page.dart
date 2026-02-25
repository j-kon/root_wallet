import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';

class ConfirmSendPage extends ConsumerWidget {
  const ConfirmSendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendFormProvider);
    final notifier = ref.read(sendFormProvider.notifier);

    if (state.builtPsbt == null) {
      return AppScaffold(
        title: 'Confirm',
        body: const EmptyState(message: 'No transaction prepared yet.'),
      );
    }

    return AppScaffold(
      title: 'Confirm Send',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('To: ${state.address}'),
                    const SizedBox(height: 8),
                    Text('Amount: ${state.amountText} sats'),
                    const SizedBox(height: 8),
                    Text('Fee: ${state.feeRate.satsPerVByte} sat/vB'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            PrimaryButton(
              label: state.isSubmitting ? 'Broadcasting...' : 'Broadcast',
              onPressed: state.isSubmitting
                  ? null
                  : () async {
                      final txId = await notifier.signAndBroadcast();
                      if (!context.mounted || txId == null) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Broadcasted: $txId')),
                      );

                      Navigator.of(
                        context,
                      ).popUntil(ModalRoute.withName(AppRoutes.walletHome));
                    },
            ),
          ],
        ),
      ),
    );
  }
}
