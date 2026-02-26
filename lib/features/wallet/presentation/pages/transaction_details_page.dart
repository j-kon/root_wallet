import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/shared/widgets/copy_row.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! TxItem) {
      return const AppScaffold(
        title: 'Transaction',
        body: EmptyState(
          title: 'Transaction not found',
          message: 'Unable to load transaction details.',
        ),
      );
    }

    final tx = args;
    final btcAmount = tx.amountSats / AppConstants.satoshisPerBitcoin;
    final statusLabel = tx.isPending ? 'Pending' : 'Confirmed';
    final explorerUri = Uri.parse('https://mempool.space/testnet/tx/${tx.txId}');

    return AppScaffold(
      title: 'Transaction',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: tx.isPending
                    ? AppColors.warning.withValues(alpha: 0.16)
                    : AppColors.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tx.isPending
                      ? Colors.brown.shade800
                      : Colors.green.shade900,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Amount',
                      value: AppFormatters.btc(btcAmount),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Amount (sats)',
                      value: AppFormatters.sats(tx.amountSats),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Confirmations',
                      value: tx.confirmations?.toString() ?? '--',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Fee',
                      value: tx.feeSats == null
                          ? '--'
                          : AppFormatters.sats(tx.feeSats!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Date',
                      value: AppDateTime.ymdHm(tx.timestamp),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Direction',
                      value: tx.isIncoming ? 'Received' : 'Sent',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CopyRow(value: tx.txId, label: 'TXID'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final launched = await launchUrl(
                  explorerUri,
                  mode: LaunchMode.externalApplication,
                );
                if (launched || !context.mounted) {
                  return;
                }

                await Clipboard.setData(
                  ClipboardData(text: explorerUri.toString()),
                );
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open browser. Explorer link copied.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('View on explorer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
