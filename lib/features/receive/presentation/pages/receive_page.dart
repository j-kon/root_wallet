import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/receive/presentation/widgets/address_qr.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class ReceivePage extends ConsumerWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletControllerProvider);

    return AppScaffold(
      title: 'Receive',
      body: walletState.when(
        loading: () => const Loading(),
        error: (_, _) => const Center(child: Text('Unable to load address')),
        data: (data) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AddressQr(address: data.receiveAddress),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Address',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(data.receiveAddress),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: data.receiveAddress),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Address copied'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Share coming soon. Address copied instead.',
                                      ),
                                    ),
                                  );
                                  Clipboard.setData(
                                    ClipboardData(text: data.receiveAddress),
                                  );
                                },
                                icon: const Icon(Icons.share_rounded),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const InfoBanner(
                  type: InfoBannerType.warning,
                  message: 'Only send BTC to this address.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
