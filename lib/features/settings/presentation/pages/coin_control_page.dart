import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class CoinControlPage extends ConsumerWidget {
  const CoinControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utxosAsync = ref.watch(walletUtxosProvider);
    final lockedUtxosAsync = ref.watch(lockedUtxosProvider);

    return AppScaffold(
      title: 'Coin Control',
      actions: [
        IconButton(
          tooltip: 'Refresh coins',
          onPressed: () => ref.invalidate(walletUtxosProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: utxosAsync.when(
        loading: () => const Loading(label: 'Loading unspent outputs...'),
        error: (error, stackTrace) => EmptyState(
          title: 'UTXOs unavailable',
          message: 'Could not load wallet unspent outputs right now.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(walletUtxosProvider),
          icon: Icons.toll_rounded,
        ),
        data: (utxos) {
          if (utxos.isEmpty) {
            return const EmptyState(
              title: 'No unspent outputs',
              message: 'Your wallet has no UTXOs yet. Receive some bitcoin to start.',
              icon: Icons.toll_rounded,
            );
          }

          final lockedUtxos = lockedUtxosAsync.valueOrNull ?? {};

          // Calculate total confirmed vs total locked
          var totalSats = 0;
          var lockedSats = 0;
          for (final utxo in utxos) {
            final value = utxo.txout.value.toSat();
            totalSats += value;
            final outpointStr = '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
            if (lockedUtxos.contains(outpointStr)) {
              lockedSats += value;
            }
          }

          final spendableSats = totalSats - lockedSats;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              AppSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing,
            ),
            children: [
              // Summary card
              GlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                tint: AppColors.glassSurfaceStrongOf(context).withValues(
                  alpha: AppColors.isDark(context) ? 0.62 : 0.96,
                ),
                highlightOpacity: 0.05,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UTXO spend control',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Lock UTXOs to prevent them from being spent in automatic coin selection. Locked UTXOs are excluded from your spendable balance.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(
                          label: 'Total balance',
                          value: AppFormatters.sats(totalSats),
                        ),
                        _StatItem(
                          label: 'Locked',
                          value: AppFormatters.sats(lockedSats),
                          color: AppColors.danger,
                        ),
                        _StatItem(
                          label: 'Spendable',
                          value: AppFormatters.sats(spendableSats),
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Available outputs (${utxos.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...utxos.map((utxo) {
                final outpointStr = '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
                final isLocked = lockedUtxos.contains(outpointStr);
                final sats = utxo.txout.value.toSat();
                final isConfirmed = utxo.chainPosition is bdk.ConfirmedChainPosition;
                
                String addressStr = 'Unknown';
                try {
                  final address = bdk.Address.fromScript(
                    script: utxo.txout.scriptPubkey,
                    network: bdk.Network.testnet,
                  );
                  addressStr = address.toString();
                } catch (e) {
                  addressStr = 'Address parsing error';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    tint: isLocked
                        ? Colors.red.withValues(alpha: AppColors.isDark(context) ? 0.05 : 0.02)
                        : AppColors.glassSurfaceOf(context).withValues(
                            alpha: AppColors.isDark(context) ? 0.58 : 0.95,
                          ),
                    borderColor: isLocked
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : AppColors.glassBorderOf(context),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppFormatters.sats(sats),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isLocked ? AppColors.danger : null,
                                  ),
                            ),
                            IconButton(
                              tooltip: isLocked ? 'Unlock UTXO' : 'Lock UTXO',
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await ref
                                    .read(lockedUtxosProvider.notifier)
                                    .toggleUtxo(outpointStr);
                              },
                              icon: Icon(
                                isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                color: isLocked ? AppColors.danger : AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppFormatters.btcFromSats(sats),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                        ),
                        const Divider(height: AppSpacing.md),
                        _InfoRow(
                          label: 'Address',
                          value: AppFormatters.maskAddress(addressStr),
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: addressStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address copied.')),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _InfoRow(
                          label: 'Outpoint',
                          value: AppFormatters.maskAddress(outpointStr),
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: outpointStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Outpoint copied.')),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isConfirmed
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isConfirmed ? 'Confirmed' : 'Pending',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isConfirmed ? AppColors.success : AppColors.warning,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
        ),
        GestureDetector(
          onTap: onCopy,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
