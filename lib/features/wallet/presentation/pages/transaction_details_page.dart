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
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceRaised = AppColors.surfaceRaisedOf(context);
    final border = AppColors.borderOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
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
    final explorerUri = Uri.parse(AppConstants.testnetExplorerTxUrl(tx.txId));
    final shareBody =
        'Bitcoin testnet transaction\n'
        'TXID: ${tx.txId}\n'
        '${explorerUri.toString()}';
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
          GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            tint: AppColors.glassSurfaceStrongOf(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.95),
            highlightOpacity: 0.05,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Stack(
              children: [
                Positioned(
                  top: -34,
                  right: -20,
                  child: _DetailsOrb(
                    size: 140,
                    color:
                        (tx.isPending ? AppColors.warning : AppColors.primary)
                            .withValues(alpha: 0.20),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -32,
                  child: _DetailsOrb(
                    size: 112,
                    color: AppColors.accent.withValues(alpha: 0.12),
                  ),
                ),
                Column(
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
                        const _TxHeroBadge(
                          icon: Icons.language_rounded,
                          label: 'Testnet',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      amountLabel,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      satsLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppDateTime.ymdHm(tx.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
                    color: surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: border),
                  ),
                  child: SelectableText(
                    tx.txId,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (context.isCompactWidth) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyTxId(context, tx.txId),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy TXID'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final shared = await ref
                            .read(shareServiceProvider)
                            .shareText(
                              shareBody,
                              subject: 'Root Wallet transaction',
                            );
                        if (shared || !context.mounted) {
                          return;
                        }
                        await _copyExplorerLink(context, explorerUri);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share transaction'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openExplorer(context, ref, explorerUri),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open explorer'),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyTxId(context, tx.txId),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy TXID'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            final shared = await ref
                                .read(shareServiceProvider)
                                .shareText(
                                  shareBody,
                                  subject: 'Root Wallet transaction',
                                );
                            if (shared || !context.mounted) {
                              return;
                            }
                            await _copyExplorerLink(context, explorerUri);
                          },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _openExplorer(context, ref, explorerUri),
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

  Future<void> _copyTxId(BuildContext context, String txId) async {
    await Clipboard.setData(ClipboardData(text: txId));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('TXID copied.')));
  }

  Future<void> _copyExplorerLink(BuildContext context, Uri explorerUri) async {
    await Clipboard.setData(ClipboardData(text: explorerUri.toString()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Explorer link copied.')));
  }

  Future<void> _openExplorer(
    BuildContext context,
    WidgetRef ref,
    Uri explorerUri,
  ) async {
    final launched = await ref
        .read(urlLauncherServiceProvider)
        .openExternalUrl(explorerUri);
    if (launched || !context.mounted) {
      return;
    }
    await _copyExplorerLink(context, explorerUri);
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

class _TxHeroBadge extends StatelessWidget {
  const _TxHeroBadge({required this.icon, required this.label});

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

class _DetailsOrb extends StatelessWidget {
  const _DetailsOrb({required this.size, required this.color});

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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

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
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
