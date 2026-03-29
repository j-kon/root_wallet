import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
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
    final hideBalances = ref.watch(balancePrivacyProvider).valueOrNull ?? false;
    final explorerUri = Uri.parse(
      'https://mempool.space/testnet/tx/${tx.txId}',
    );
    final amountBtc = tx.amountSats / AppConstants.satoshisPerBitcoin;
    final amountLabel = hideBalances
        ? AppFormatters.obscuredBtc()
        : AppFormatters.btc(amountBtc);
    final satsLabel = hideBalances
        ? AppFormatters.obscuredSats()
        : AppFormatters.sats(tx.amountSats);
    final feeLabel = tx.feeSats == null
        ? '--'
        : hideBalances
        ? AppFormatters.obscuredSats()
        : AppFormatters.sats(tx.feeSats!);
    final statusLabel = tx.isPending ? 'Pending' : 'Confirmed';
    final directionLabel = tx.isIncoming ? 'Received BTC' : 'Sent BTC';

    return AppScaffold(
      title: 'Transaction',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tx.isPending
                    ? [Colors.brown.shade700, AppColors.warning]
                    : [AppColors.secondary, AppColors.primary],
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _TxHeroBadge(
                      icon: tx.isIncoming
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      label: directionLabel,
                    ),
                    _TxHeroBadge(
                      icon: tx.isPending
                          ? Icons.timelapse_rounded
                          : Icons.verified_rounded,
                      label: statusLabel,
                    ),
                    _TxHeroBadge(
                      icon: Icons.language_rounded,
                      label: 'Testnet',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  amountLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  satsLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppDateTime.ymdHm(tx.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            type: tx.isPending
                ? InfoBannerType.warning
                : InfoBannerType.success,
            message: tx.isPending
                ? 'This transaction is still pending. Finality improves as confirmations increase.'
                : 'This transaction is confirmed and visible on the network.',
            icon: tx.isPending
                ? Icons.hourglass_bottom_rounded
                : Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailsPanel(
            title: 'Breakdown',
            subtitle: 'Operational details for this transaction.',
            child: Column(
              children: [
                _DetailRow(label: 'Direction', value: directionLabel),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(label: 'Status', value: statusLabel),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Confirmations',
                  value: '${tx.confirmations ?? 0}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(label: 'Network fee', value: feeLabel),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  label: 'Timestamp',
                  value: AppDateTime.ymdHm(tx.timestamp),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _DetailRow(label: 'Network', value: 'Bitcoin testnet'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailsPanel(
            title: 'Transaction fingerprint',
            subtitle: 'Use the TXID to verify the record externally.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    tx.txId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: tx.txId));
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('TXID copied.')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy TXID'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
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
                              content: Text('Explorer link copied.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open explorer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
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

class _TxHeroBadge extends StatelessWidget {
  const _TxHeroBadge({required this.icon, required this.label});

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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

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
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
