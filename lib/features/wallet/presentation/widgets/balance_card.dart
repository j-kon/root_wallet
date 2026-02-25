import 'package:flutter/material.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.balance, this.onReceiveTap});

  final Balance balance;
  final VoidCallback? onReceiveTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total balance',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${balance.btc.toStringAsFixed(8)} BTC',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('${balance.totalSats} sats'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReceiveTap,
              icon: const Icon(Icons.qr_code),
              label: const Text('Receive'),
            ),
          ],
        ),
      ),
    );
  }
}
