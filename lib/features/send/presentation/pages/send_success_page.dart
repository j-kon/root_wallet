import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

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

class SendSuccessPage extends ConsumerWidget {
  const SendSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceRaised = AppColors.surfaceRaisedOf(context);
    final border = AppColors.borderOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! SendSuccessPageArgs) {
      return const AppScaffold(
        title: 'Transfer sent',
        body: Center(child: Text('Transfer details unavailable.')),
      );
    }

    final explorerUri = Uri.parse(AppConstants.testnetExplorerTxUrl(args.txId));
    final shareBody =
        'Bitcoin testnet transfer\n'
        'TXID: ${args.txId}\n'
        '${explorerUri.toString()}';
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
                    GlassSurface(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      tint: AppColors.glassSurfaceStrongOf(context).withValues(
                        alpha: AppColors.isDark(context) ? 0.62 : 0.95,
                      ),
                      highlightOpacity: 0.05,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -32,
                            right: -18,
                            child: _SuccessOrb(
                              size: 140,
                              color: AppColors.primary.withValues(alpha: 0.20),
                            ),
                          ),
                          Positioned(
                            bottom: -42,
                            left: -34,
                            child: _SuccessOrb(
                              size: 110,
                              color: AppColors.accent.withValues(alpha: 0.12),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SuccessBadge(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Broadcast complete',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Your transfer is now pending on Bitcoin testnet.',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'You can track the TXID below or open it in the public explorer.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  const _SuccessBadge(
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
                              color: surfaceRaised,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: border),
                            ),
                            child: SelectableText(
                              args.txId,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: textSecondary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (context.isCompactWidth) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _copyTxId(context, args.txId),
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
                                        subject: 'Root Wallet transfer',
                                      );
                                  if (shared || !context.mounted) {
                                    return;
                                  }
                                  await _copyExplorerLink(context, explorerUri);
                                },
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Share tracking link'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _openExplorer(context, ref, explorerUri),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('View on explorer'),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _copyTxId(context, args.txId),
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
                                            subject: 'Root Wallet transfer',
                                          );
                                      if (shared || !context.mounted) {
                                        return;
                                      }
                                      await _copyExplorerLink(
                                        context,
                                        explorerUri,
                                      );
                                    },
                                    icon: const Icon(Icons.share_outlined),
                                    label: const Text('Share'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _openExplorer(
                                      context,
                                      ref,
                                      explorerUri,
                                    ),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('View on explorer'),
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

  Future<void> _copyTxId(BuildContext context, String txId) async {
    await Clipboard.setData(ClipboardData(text: txId));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('TXID copied.')));
  }

  Future<void> _copyExplorerLink(BuildContext context, Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
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
    Uri uri,
  ) async {
    final launched = await ref
        .read(urlLauncherServiceProvider)
        .openExternalUrl(uri);
    if (launched || !context.mounted) {
      return;
    }
    await _copyExplorerLink(context, uri);
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
            color: emphasized ? textPrimary : textSecondary,
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
                  fontWeight: FontWeight.w700,
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

class _SuccessOrb extends StatelessWidget {
  const _SuccessOrb({required this.size, required this.color});

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
