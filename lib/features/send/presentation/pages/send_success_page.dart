import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:url_launcher/url_launcher.dart';

class SendSuccessPageArgs {
  const SendSuccessPageArgs({
    required this.txId,
    required this.amountSats,
    required this.feeSats,
    required this.sentAt,
  });

  final String txId;
  final int amountSats;
  final int feeSats;
  final DateTime sentAt;
}

class SendSuccessPage extends StatelessWidget {
  const SendSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shadow = AppColors.shadowOf(context);
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! SendSuccessPageArgs) {
      return const AppScaffold(
        title: 'Transfer sent',
        body: Center(child: Text('Transfer details unavailable.')),
      );
    }

    final explorerUri = Uri.parse(AppConstants.testnetExplorerTxUrl(args.txId));
    final totalSats = args.amountSats + args.feeSats;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _goHome(context);
      },
      child: AppScaffold(
        title: 'Transfer sent',
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
                        boxShadow: [
                          BoxShadow(
                            color: shadow,
                            blurRadius: 24,
                            offset: const Offset(0, 14),
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
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              'Broadcast complete',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Your transfer is now pending on Bitcoin testnet.',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'You can track the TXID below or open it in the public explorer.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              _SuccessBadge(
                                icon: Icons.schedule_rounded,
                                label: 'Pending',
                              ),
                              _SuccessBadge(
                                icon: Icons.payments_outlined,
                                label: AppFormatters.sats(totalSats),
                              ),
                              const _SuccessBadge(
                                icon: Icons.language_rounded,
                                label: 'Testnet',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SuccessPanel(
                      title: 'Transfer summary',
                      subtitle: 'This is what was submitted to the network.',
                      child: Column(
                        children: [
                          _SuccessRow(
                            label: 'Amount',
                            value: AppFormatters.btcFromSats(args.amountSats),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SuccessRow(
                            label: 'Network fee',
                            value: AppFormatters.sats(args.feeSats),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SuccessRow(
                            label: 'Total debit',
                            value: AppFormatters.sats(totalSats),
                            emphasized: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SuccessPanel(
                      title: 'Transaction ID',
                      subtitle:
                          'Share this only for tracking. It does not give access to your funds.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: border),
                            ),
                            child: SelectableText(args.txId),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: args.txId),
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('TXID copied.'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy TXID'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _openExplorer(context, explorerUri),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('View explorer'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDetails(context, args),
                      child: const Text('View transaction'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _goHome(context),
                      child: const Text('Back to wallet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExplorer(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Explorer link copied.')));
  }

  void _goHome(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.walletHome, (route) => false);
  }

  void _openDetails(BuildContext context, SendSuccessPageArgs args) {
    Navigator.of(context).pushNamed(
      AppRoutes.transactionDetails,
      arguments: TxItem(
        txId: args.txId,
        amountSats: args.amountSats,
        timestamp: args.sentAt,
        isIncoming: false,
        status: TxItemStatus.pending,
        feeSats: args.feeSats,
        confirmations: 0,
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final shadow = AppColors.shadowOf(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 10)),
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

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({
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
    final textPrimary = AppColors.textPrimaryOf(context);

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
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: textPrimary,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.icon, required this.label});

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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
