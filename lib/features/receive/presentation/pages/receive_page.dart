import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/receive/presentation/widgets/address_qr.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/widgets/copy_row.dart';

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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AddressQr(address: data.receiveAddress),
                const SizedBox(height: 16),
                CopyRow(value: data.receiveAddress, label: 'Address'),
              ],
            ),
          );
        },
      ),
    );
  }
}
