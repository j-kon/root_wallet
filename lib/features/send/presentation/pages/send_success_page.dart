import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
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
    final isDark = AppColors.isDark(context);
    final textPrimary =
        isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine;
    final textSecondary =
        isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68);
    final cardBg =
        isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite;
    final borderColor =
        isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC);

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! SendSuccessPageArgs) {
      return const AppScaffold(
        title: 'Transfer sent',
        body: Center(child: Text('Transfer details unavailable.')),
      );
    }

    final explorerUri = Uri.parse(AppConstants.testnetExplorerTxUrl(args.txId));
    final shareBody =
        '${AppConstants.bitcoinNetworkDisplayName} transfer\n'
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
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.pageHorizontalPadding,
                  RootSpacing.sm,
                  context.pageHorizontalPadding,
                  RootSpacing.md,
                ),
                children: [
                  // 1. Hero / Header Card
                  Container(
                    padding: const EdgeInsets.all(RootSpacing.lg),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(RootRadius.lg),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        // Success checkmark badge
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: RootBrandColors.pineGreen
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: RootBrandColors.pineGreen,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: RootSpacing.md),

                        // Primary amount
                        Text(
                          AppFormatters.btcFromSats(args.amountSats),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Secondary sats amount
                        Text(
                          '${AppFormatters.sats(args.amountSats)} (+ ${AppFormatters.sats(args.feeSats)} fee)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: RootSpacing.md),

                        // Status & Network badges row
                        Wrap(
                          spacing: RootSpacing.xs,
                          runSpacing: RootSpacing.xs,
                          alignment: WrapAlignment.center,
                          children: [
                            _StatusPill(
                              isDark: isDark,
                              dotColor: RootBrandColors.amberAccent,
                              label: 'Pending',
                            ),
                            _StatusPill(
                              isDark: isDark,
                              icon: Icons.payments_outlined,
                              label: AppFormatters.sats(totalSats),
                            ),
                            _StatusPill(
                              isDark: isDark,
                              icon: Icons.language_rounded,
                              label: AppConstants.networkDisplayName,
                            ),
                          ],
                        ),
                        const SizedBox(height: RootSpacing.sm),

                        Text(
                          'Your transfer is broadcast and awaiting confirmation on Bitcoin testnet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RootSpacing.md),

                  // 2. Transfer Summary Panel
                  _SectionCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    title: 'Transfer summary',
                    subtitle: 'This is what was submitted to the network.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Amount',
                          value: AppFormatters.btcFromSats(args.amountSats),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(height: RootSpacing.sm),
                        _SummaryRow(
                          label: 'Network fee',
                          value: AppFormatters.sats(args.feeSats),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(height: RootSpacing.sm),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: RootSpacing.sm),
                        _SummaryRow(
                          label: 'Total debit',
                          value: AppFormatters.sats(totalSats),
                          emphasized: true,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RootSpacing.md),

                  // 3. Transaction ID Card & Action Buttons
                  _SectionCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    title: 'Transaction ID',
                    subtitle:
                        'Share this only for tracking. It does not give access to your funds.',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // TXID Box with one-touch copy
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RootSpacing.md,
                            vertical: RootSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? RootBrandColors.deepForest
                                : RootBrandColors.warmIvory,
                            borderRadius: BorderRadius.circular(RootRadius.md),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  args.txId,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    height: 1.4,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: 'Copy TXID',
                                color: textSecondary,
                                onPressed: () => _copyTxId(context, args.txId),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: RootSpacing.md),

                        // Action Buttons: 2 balanced horizontal buttons + full width explorer button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyTxId(context, args.txId),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text(
                                  'Copy TXID',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: RootSpacing.sm),
                            Expanded(
                              child: OutlinedButton.icon(
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
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Share',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RootSpacing.xs),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                _openExplorer(context, ref, explorerUri),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                            ),
                            label: const Text('View on explorer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Pinned Bottom Navigation Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                RootSpacing.sm,
                context.pageHorizontalPadding,
                context.contentBottomSpacing,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? RootBrandColors.charcoalPine
                    : RootBrandColors.warmIvory,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _openDetails(context, args),
                        child: const Text('View transaction'),
                      ),
                    ),
                  ),
                  const SizedBox(width: RootSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: RootBrandColors.pineGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _goHome(context),
                        child: const Text('Back to wallet'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyTxId(BuildContext context, String txId) async {
    await Clipboard.setData(ClipboardData(text: txId));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TXID copied to clipboard.')),
    );
  }

  Future<void> _copyExplorerLink(BuildContext context, Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Explorer link copied.')),
    );
  }

  Future<void> _openExplorer(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    final launched =
        await ref.read(urlLauncherServiceProvider).openExternalUrl(uri);
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.isDark,
    required this.label,
    this.dotColor,
    this.icon,
  });

  final bool isDark;
  final String label;
  final Color? dotColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine;
    final borderColor =
        isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC);
    final bgColor =
        isDark ? RootBrandColors.deepForest : RootBrandColors.warmIvory;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: RootBrandColors.pineGreen),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.cardBg,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
    required this.child,
  });

  final Color cardBg;
  final Color borderColor;
  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: textSecondary,
            ),
          ),
        ),
        const SizedBox(width: RootSpacing.sm),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 14.5 : 13.5,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            color: emphasized ? textPrimary : textSecondary,
          ),
        ),
      ],
    );
  }
}
