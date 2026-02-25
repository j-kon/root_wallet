import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class RestoreWalletPage extends ConsumerStatefulWidget {
  const RestoreWalletPage({super.key});

  @override
  ConsumerState<RestoreWalletPage> createState() => _RestoreWalletPageState();
}

class _RestoreWalletPageState extends ConsumerState<RestoreWalletPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Restore Wallet',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recovery phrase',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Restore',
              onPressed: () async {
                final phrase = _controller.text.trim();
                if (phrase.isEmpty) {
                  return;
                }

                final wallet = await ref
                    .read(restoreWalletUsecaseProvider)
                    .call(phrase);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restored: ${wallet.fingerprint}')),
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
