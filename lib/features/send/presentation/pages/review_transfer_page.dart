import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';

class ReviewTransferPage extends ConsumerWidget {
  const ReviewTransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendControllerProvider);
    final controller = ref.read(sendControllerProvider.notifier);
    final btcNgnRate = ref.watch(btcNgnRateProvider);

    if (!state.canReview || state.amountSats == null) {
      return const AppScaffold(
        title: 'Review transfer',
        body: EmptyState(
          title: 'Nothing to review',
          message: 'Enter a valid recipient and amount first.',
        ),
      );
    }

    final amountSats = state.amountSats!;
    final amountBtc = amountSats / AppConstants.satoshisPerBitcoin;
    final totalSats = state.totalSats ?? amountSats;
    final totalBtc = totalSats / AppConstants.satoshisPerBitcoin;
    final fiatText = btcNgnRate.when(
      data: (rate) => '≈ ${AppFormatters.ngn(amountBtc * rate.value)}',
      loading: () => '≈ —',
      error: (_, _) => '≈ —',
    );
    const networkLabel = 'Testnet';

    return AppScaffold(
      title: 'Review transfer',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipient',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppFormatters.maskAddress(state.draft.address),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy address',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: state.draft.address),
                            );
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address copied')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg),
                    _ReviewRow(
                      label: 'Amount',
                      value: AppFormatters.btc(amountBtc),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewRow(
                      label: 'Amount (sats)',
                      value: AppFormatters.sats(amountSats),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewRow(label: 'Fiat', value: fiatText),
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewRow(
                      label: 'Fee rate',
                      value: '${state.draft.feeRate.satsPerVByte} sat/vB',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewRow(
                      label: 'Estimated fee',
                      value: AppFormatters.sats(state.estimatedFeeSats),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewRow(
                      label: 'Total',
                      value:
                          '${AppFormatters.btc(totalBtc)} (${AppFormatters.sats(totalSats)})',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        networkLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.errorMessage != null)
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
            const Spacer(),
            PrimaryButton(
              label: state.isSending ? 'Sending...' : 'Confirm & send',
              onPressed: state.isSending
                  ? null
                  : () async {
                      final txId = await controller.send();
                      if (txId == null || !context.mounted) {
                        return;
                      }

                      controller.resetAfterSuccess();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.walletHome,
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sent successfully. TXID: $txId'),
                        ),
                      );
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: state.isSending
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}
