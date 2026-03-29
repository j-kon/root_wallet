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
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class ReviewTransferPage extends ConsumerWidget {
  const ReviewTransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendControllerProvider);
    final controller = ref.read(sendControllerProvider.notifier);
    final btcNgnRate = ref.watch(btcNgnRateProvider);
    final walletState = ref.watch(walletControllerProvider);

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
    final remainingSats = walletState.valueOrNull?.balance.confirmedSats == null
        ? null
        : walletState.valueOrNull!.balance.confirmedSats - totalSats;
    final fiatText = btcNgnRate.when(
      data: (rate) => AppFormatters.ngn(amountBtc * rate.value),
      loading: () => 'Loading...',
      error: (_, _) => 'Unavailable',
    );

    return AppScaffold(
      title: 'Review transfer',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.secondary,
                          AppColors.primaryDeep,
                          AppColors.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 24,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Final confirmation',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'You are about to send ${AppFormatters.btc(amountBtc)}.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Double-check the address, amount, and fee before broadcasting.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _ReviewBadge(
                              icon: Icons.currency_exchange_rounded,
                              label: fiatText,
                            ),
                            _ReviewBadge(
                              icon: Icons.speed_rounded,
                              label:
                                  '${state.draft.feeRate.satsPerVByte} sat/vB',
                            ),
                            const _ReviewBadge(
                              icon: Icons.language_rounded,
                              label: 'Testnet',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ReviewPanel(
                    title: 'Recipient',
                    subtitle:
                        'Make sure the address matches the intended destination.',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.draft.address,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
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
                                  const SnackBar(
                                    content: Text('Recipient address copied.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const InfoBanner(
                          type: InfoBannerType.warning,
                          message:
                              'Verify the first and last characters of the destination address before sending.',
                          icon: Icons.fact_check_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ReviewPanel(
                    title: 'Transfer breakdown',
                    subtitle: 'The total debit includes the network fee.',
                    child: Column(
                      children: [
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
                        _ReviewRow(label: 'Approx. fiat', value: fiatText),
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
                        const Divider(height: AppSpacing.lg),
                        _ReviewRow(
                          label: 'Total debit',
                          value:
                              '${AppFormatters.btc(totalBtc)} (${AppFormatters.sats(totalSats)})',
                          emphasized: true,
                        ),
                        if (remainingSats != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _ReviewRow(
                            label: 'Remaining confirmed balance',
                            value: remainingSats >= 0
                                ? AppFormatters.btcFromSats(remainingSats)
                                : 'Insufficient balance',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoBanner(
                      type: InfoBannerType.error,
                      message: state.errorMessage!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: state.isSending
                  ? 'Broadcasting...'
                  : 'Confirm & broadcast',
              onPressed: state.isSending
                  ? null
                  : () async {
                      final txId = await controller.send();
                      if (txId == null || !context.mounted) {
                        return;
                      }

                      controller.resetAfterSuccess();
                      await ref
                          .read(walletHomeControllerProvider.notifier)
                          .sync();
                      if (!context.mounted) {
                        return;
                      }

                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.walletHome,
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction broadcast successfully.'),
                        ),
                      );
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: state.isSending
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Edit details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (emphasized
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
