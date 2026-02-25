import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class CreateWalletPage extends ConsumerWidget {
  const CreateWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Create Wallet',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new wallet identity and secure it before first receive.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Create',
              onPressed: () async {
                final identity = await ref
                    .read(createWalletUsecaseProvider)
                    .call();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Wallet created: ${identity.fingerprint}'),
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
