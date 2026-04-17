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
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/send/presentation/pages/send_success_page.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class ReviewTransferPage extends ConsumerWidget {
  const ReviewTransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimaryOf(context);
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
      error: (error, stackTrace) => 'Unavailable',
    );

    return AppScaffold(
      title: 'Review transfer',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  GlassSurface(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    tint: AppColors.glassSurfaceStrongOf(context).withValues(
                      alpha: AppColors.isDark(context) ? 0.62 : 0.95,
                    ),
                    highlightOpacity: 0.05,
                    padding: EdgeInsets.all(
                      context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -34,
                          right: -22,
                          child: _HeroOrb(
                            size: 140,
                            color: AppColors.primary.withValues(alpha: 0.20),
                          ),
                        ),
                        Positioned(
                          bottom: -44,
                          left: -38,
                          child: _HeroOrb(
                            size: 120,
                            color: AppColors.accent.withValues(alpha: 0.12),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ReviewBadge(
                              icon: Icons.verified_user_outlined,
                              label: 'Final confirmation',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'You are about to send ${AppFormatters.btc(amountBtc)}.',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Double-check the address, amount, and fee before broadcasting.',
                              style: Theme.of(context).textTheme.bodyMedium,
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
                                  label: AppConstants.networkDisplayName,
                                ),
                              ],
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
                                      color: textPrimary,
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
                      final amountSatsToSend = amountSats;
                      final estimatedFeeSats = state.estimatedFeeSats;
                      final sentAt = DateTime.now();
                      final txId = await controller.send();
                      if (txId == null || !context.mounted) {
                        return;
                      }

                      await ref
                          .read(walletHomeControllerProvider.notifier)
                          .recordPendingSend(
                            txId: txId,
                            amountSats: amountSatsToSend,
                            feeSats: estimatedFeeSats,
                            timestamp: sentAt,
                          );
                      controller.resetAfterSuccess();
                      if (!context.mounted) {
                        return;
                      }

                      Navigator.of(context).pushReplacementNamed(
                        AppRoutes.sendSuccess,
                        arguments: SendSuccessPageArgs(
                          txId: txId,
                          amountSats: amountSatsToSend,
                          feeSats: estimatedFeeSats,
                          sentAt: sentAt,
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
            SizedBox(height: context.navBarBottomSpacing),
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
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
      highlightOpacity: 0.05,
      padding: const EdgeInsets.all(AppSpacing.md),
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
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 224.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        tint: AppColors.glassSurfaceOf(
          context,
        ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.88),
        borderColor: AppColors.glassBorderOf(context).withValues(alpha: 0.72),
        shadowColor: Colors.transparent,
        highlightOpacity: 0.03,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryOf(context)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                  fontSize: context.isVeryCompactWidth ? 11.5 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
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
    final textSecondary = AppColors.textSecondaryOf(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textSecondary),
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
