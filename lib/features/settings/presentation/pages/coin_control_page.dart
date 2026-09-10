import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class CoinControlPage extends ConsumerWidget {
  const CoinControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utxosAsync = ref.watch(walletUtxosProvider);
    final lockedUtxosAsync = ref.watch(lockedUtxosProvider);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Coin Control',
      actions: [
        IconButton(
          tooltip: 'Refresh coins',
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.invalidate(walletUtxosProvider);
          },
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
              message:
                  'Your wallet has no UTXOs yet. Receive some bitcoin to start.',
              icon: Icons.toll_rounded,
            );
          }

          final lockedUtxos = lockedUtxosAsync.valueOrNull ?? {};

          var totalSats = 0;
          var lockedSats = 0;
          for (final utxo in utxos) {
            final value = utxo.txout.value.toSat();
            totalSats += value;
            final outpointStr =
                '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
            if (lockedUtxos.contains(outpointStr)) {
              lockedSats += value;
            }
          }

          final spendableSats = totalSats - lockedSats;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              RootSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing,
            ),
            children: [
              // 1. Solid Summary & Spend Control Hero Card
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? RootBrandColors.nightPine
                      : RootBrandColors.pureWhite,
                  borderRadius: BorderRadius.circular(RootRadius.lg),
                  border: Border.all(
                    color: isDark
                        ? RootBrandColors.borderPine
                        : const Color(0xFFD7E3DC),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(RootSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UTXO spend control',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lock UTXOs to prevent them from being spent in automatic coin selection. Locked UTXOs are excluded from your spendable balance.',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: RootSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(RootSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark
                            ? RootBrandColors.slatePine
                            : const Color(0xFFF4F7F5),
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatItem(
                            label: 'Total balance',
                            value: AppFormatters.sats(totalSats),
                          ),
                          _StatItem(
                            label: 'Locked',
                            value: AppFormatters.sats(lockedSats),
                            color: RootBrandColors.error,
                          ),
                          _StatItem(
                            label: 'Spendable',
                            value: AppFormatters.sats(spendableSats),
                            color: RootBrandColors.pineGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: RootSpacing.lg),

              Text(
                'Available outputs (${utxos.length})',
                style: TextStyle(
                  color: isDark
                      ? RootBrandColors.warmIvory
                      : RootBrandColors.charcoalPine,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: RootSpacing.sm),

              ...utxos.map((utxo) {
                final outpointStr =
                    '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
                final isLocked = lockedUtxos.contains(outpointStr);
                final sats = utxo.txout.value.toSat();
                final isConfirmed =
                    utxo.chainPosition is bdk.ConfirmedChainPosition;

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
                  padding: const EdgeInsets.only(bottom: RootSpacing.md),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? RootBrandColors.nightPine
                          : RootBrandColors.pureWhite,
                      borderRadius: BorderRadius.circular(RootRadius.lg),
                      border: Border.all(
                        color: isLocked
                            ? RootBrandColors.amberAccent.withValues(alpha: 0.6)
                            : isDark
                                ? RootBrandColors.borderPine
                                : const Color(0xFFD7E3DC),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.all(RootSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppFormatters.sats(sats),
                                  style: TextStyle(
                                    color: isLocked
                                        ? RootBrandColors.amberAccent
                                        : isDark
                                            ? RootBrandColors.warmIvory
                                            : RootBrandColors.charcoalPine,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.btcFromSats(sats),
                                  style: TextStyle(
                                    color: isDark
                                        ? RootBrandColors.mutedSage
                                        : const Color(0xFF5E6F68),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            MagneticPressable(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                await ref
                                    .read(lockedUtxosProvider.notifier)
                                    .toggleUtxo(outpointStr);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? RootBrandColors.amberAccent
                                          .withValues(alpha: 0.14)
                                      : isDark
                                          ? RootBrandColors.slatePine
                                          : const Color(0xFFE8EFEA),
                                  borderRadius:
                                      BorderRadius.circular(RootRadius.sm),
                                  border: Border.all(
                                    color: isLocked
                                        ? RootBrandColors.amberAccent
                                            .withValues(alpha: 0.4)
                                        : isDark
                                            ? RootBrandColors.borderPine
                                            : const Color(0xFFD7E3DC),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLocked
                                          ? Icons.lock_rounded
                                          : Icons.lock_open_rounded,
                                      size: 15,
                                      color: isLocked
                                          ? RootBrandColors.amberAccent
                                          : isDark
                                              ? RootBrandColors.warmIvory
                                              : RootBrandColors.charcoalPine,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isLocked ? 'Locked' : 'Unlocked',
                                      style: TextStyle(
                                        color: isLocked
                                            ? RootBrandColors.amberAccent
                                            : isDark
                                                ? RootBrandColors.warmIvory
                                                : RootBrandColors.charcoalPine,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 20,
                          thickness: 1,
                          color: isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                        ),
                        _InfoRow(
                          label: 'Address',
                          value: AppFormatters.maskAddress(addressStr),
                          onCopy: () {
                            HapticFeedback.lightImpact();
                            Clipboard.setData(ClipboardData(text: addressStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address copied.')),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          label: 'Outpoint',
                          value: AppFormatters.maskAddress(outpointStr),
                          onCopy: () {
                            HapticFeedback.lightImpact();
                            Clipboard.setData(ClipboardData(text: outpointStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Outpoint copied.')),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.mutedSage
                                    : const Color(0xFF5E6F68),
                                fontSize: 12,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isConfirmed
                                    ? RootBrandColors.pineGreen
                                        .withValues(alpha: 0.14)
                                    : RootBrandColors.amberAccent
                                        .withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(RootRadius.xs),
                                border: Border.all(
                                  color: isConfirmed
                                      ? RootBrandColors.pineGreen
                                          .withValues(alpha: 0.35)
                                      : RootBrandColors.amberAccent
                                          .withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                isConfirmed ? 'Confirmed' : 'Pending',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isConfirmed
                                      ? RootBrandColors.pineGreen
                                      : RootBrandColors.amberAccent,
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
  const _StatItem({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color ??
                (isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine),
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
    final isDark = AppColors.isDark(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
            fontSize: 12,
          ),
        ),
        MagneticPressable(
          onTap: onCopy,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark
                      ? RootBrandColors.warmIvory
                      : RootBrandColors.charcoalPine,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: isDark
                    ? RootBrandColors.mutedSage
                    : const Color(0xFF5E6F68),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
