import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';

class ConfirmSendPage extends ConsumerWidget {
  const ConfirmSendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendFormProvider);
    final notifier = ref.read(sendFormProvider.notifier);
    final env = ref.watch(appEnvProvider);

    if (state.builtPsbt == null) {
      return AppScaffold(
        title: 'Confirm Send',
        body: const EmptyState(
          title: 'Nothing to confirm',
          message: 'Build a transaction from Send screen first.',
        ),
      );
    }

    final amountSats = state.amountSats ?? 0;
    final amountBtc = amountSats / AppConstants.satoshisPerBitcoin;
    final feeSats = state.estimatedFeeSats;
    final totalSats = state.totalSats ?? (amountSats + feeSats);
    final totalBtc = totalSats / AppConstants.satoshisPerBitcoin;
    final networkLabel = env.isProduction ? 'Mainnet' : 'Testnet';

    return AppScaffold(
      title: 'Confirm Send',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _ConfirmRow(
                      label: 'To',
                      value: AppFormatters.maskAddress(state.address),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ConfirmRow(
                      label: 'Amount',
                      value: AppFormatters.btc(amountBtc),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ConfirmRow(
                      label: 'Fee',
                      value:
                          '$feeSats sats (${state.feeRate.satsPerVByte} sat/vB)',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ConfirmRow(
                      label: 'Total',
                      value: AppFormatters.btc(totalBtc),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ConfirmRow(label: 'Network', value: networkLabel),
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
              label: state.isSubmitting ? 'Sending...' : 'Send BTC',
              onPressed: state.isSubmitting
                  ? null
                  : () async {
                      final txId = await notifier.signAndBroadcast();
                      if (!context.mounted) {
                        return;
                      }

                      if (txId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Network error. Try again.'),
                          ),
                        );
                        return;
                      }

                      notifier.resetAfterSuccess();
                      Navigator.of(
                        context,
                      ).popUntil(ModalRoute.withName(AppRoutes.walletHome));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Transaction sent successfully. ID: $txId',
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: AppSpacing.md),
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
