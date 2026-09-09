import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/send/presentation/models/scanned_btc_uri.dart';
import 'package:root_wallet/features/send/presentation/pages/scan_address_page.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/send/presentation/widgets/fee_selector.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Send Page adhering strictly to Root Wallet Brand Guidelines.
/// Provides a solid-surface Bitcoin workflow with dual BTC/sat unit entry,
/// live NGN fiat estimates, non-truncated 3-tier fee selection, coin control,
/// and instant address format validation.
class SendPage extends ConsumerStatefulWidget {
  const SendPage({super.key});

  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  late final TextEditingController _addressController;
  late final TextEditingController _amountController;
  bool _isSatsMode = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(sendControllerProvider);
    _addressController = TextEditingController(text: state.draft.address);
    _amountController = TextEditingController(text: state.draft.amountBtcText);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _toggleUnitMode(SendController controller) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSatsMode = !_isSatsMode;
      final state = ref.read(sendControllerProvider);
      if (_isSatsMode) {
        final sats = state.amountSats;
        _amountController.text = sats == null ? '' : sats.toString();
      } else {
        _amountController.text = state.draft.amountBtcText;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(sendControllerProvider);
    final controller = ref.read(sendControllerProvider.notifier);
    final walletState = ref.watch(walletControllerProvider);
    final btcNgnRate = ref.watch(btcNgnRateProvider);

    final balance = walletState.valueOrNull?.balance;
    final spendableSats = balance?.confirmedSats ?? 0;
    final pendingSats = balance?.pendingSats ?? 0;
    final totalSats = state.totalSats;
    final remainingSats = totalSats == null ? null : spendableSats - totalSats;
    final exceedsSpendable = totalSats != null && totalSats > spendableSats;

    final estimatedNgn = btcNgnRate.when(
      data: (rate) {
        final amountBtc = state.draft.amountBtc;
        if (amountBtc == null || amountBtc <= 0) {
          return 'Enter an amount to estimate NGN value.';
        }
        return 'Approx. ${AppFormatters.ngn(amountBtc * rate.value)}';
      },
      loading: () => 'Loading FX rate...',
      error: (error, stackTrace) => 'FX rate temporarily unavailable.',
    );

    final address = state.draft.address.trim();
    final hasAddress = address.isNotEmpty;
    final addressStatusLabel = !hasAddress
        ? 'No address entered yet'
        : state.draft.looksLikeMainnetAddress
        ? 'Mainnet address detected. Testnet only.'
        : state.draft.hasValidAddress
        ? 'Looks like a valid testnet address'
        : 'Address format needs review';

    final navBarTop =
        (context.viewPadding.bottom > 0 ? 16.0 : 12.0) + 70.0;
    final buttonBottom = navBarTop + 10.0;
    final listBottomPadding = buttonBottom + 52.0 + RootSpacing.md;

    return AppScaffold(
      title: 'Send BTC',
      body: Stack(
        children: [
          // 1. Full-height scrollable list passing behind floating action
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                RootSpacing.md,
                context.pageHorizontalPadding,
                listBottomPadding,
              ),
              children: [
                // 1. Spendable Balance & Network Overview Card
                _BalanceOverviewCard(
                  isDark: isDark,
                  spendableSats: spendableSats,
                  pendingSats: pendingSats,
                  isLoading: balance == null,
                ),
                const SizedBox(height: RootSpacing.md),

                // 2. Recipient Section Card
                _RecipientCard(
                  isDark: isDark,
                  controller: _addressController,
                  hasAddress: hasAddress,
                  hasValidAddress: state.draft.hasValidAddress,
                  looksLikeMainnet: state.draft.looksLikeMainnetAddress,
                  statusLabel: addressStatusLabel,
                  onAddressChanged: (val) {
                    controller.setAddress(val);
                    // If an amount was parsed from BIP-21 URI, sync amount field
                    final updated = ref.read(sendControllerProvider);
                    if (updated.draft.amountBtcText.isNotEmpty &&
                        _amountController.text !=
                            updated.draft.amountBtcText) {
                      _amountController.text = _isSatsMode
                          ? (updated.amountSats?.toString() ?? '')
                          : updated.draft.amountBtcText;
                    }
                  },
                  onPaste: () => _pasteAddress(controller),
                  onScan: () => _scanAddress(context, controller),
                ),
                const SizedBox(height: RootSpacing.md),

                // 3. Amount Section Card with Dual BTC/Sat Switcher
                _AmountCard(
                  isDark: isDark,
                  controller: _amountController,
                  isSatsMode: _isSatsMode,
                  state: state,
                  spendableSats: spendableSats,
                  estimatedNgn: estimatedNgn,
                  onToggleUnit: () => _toggleUnitMode(controller),
                  onAmountChanged: (text) {
                    if (_isSatsMode) {
                      final parsedSats = int.tryParse(text.trim());
                      if (parsedSats != null) {
                        final btcStr = _normalizeBtcAmount(
                          parsedSats / AppConstants.satoshisPerBitcoin,
                        );
                        controller.setAmountBtc(btcStr);
                      } else if (text.trim().isEmpty) {
                        controller.setAmountBtc('');
                      }
                    } else {
                      controller.setAmountBtc(text);
                    }
                  },
                  onApplyQuickPercent: (fraction) {
                    if (spendableSats <= 0) return;
                    final targetSats = ((spendableSats * fraction).floor())
                        .clamp(0, spendableSats);
                    _applyAmountSats(targetSats, controller);
                  },
                  onApplyMax: () {
                    if (spendableSats <= state.estimatedFeeSats) return;
                    final maxSats = spendableSats - state.estimatedFeeSats;
                    _applyAmountSats(maxSats, controller);
                  },
                ),
                const SizedBox(height: RootSpacing.md),

                // 4. Network Fee Priority Card
                _FormSection(
                  isDark: isDark,
                  title: 'Network fee',
                  subtitle:
                      'Choose the balance between confirmation urgency and cost.',
                  child: const FeeSelector(),
                ),
                const SizedBox(height: RootSpacing.md),

                // 5. Coin Control / Selection Card
                _CoinSelectionCard(
                  isDark: isDark,
                  onOpenSheet: () => _showCoinSelectionSheet(context),
                ),
                const SizedBox(height: RootSpacing.md),

                // 6. Transfer Summary Card (Tested by compact_layout_regression_test)
                _TransferSummaryCard(
                  isDark: isDark,
                  state: state,
                  totalSats: totalSats,
                  remainingSats: remainingSats,
                ),

                // 7. Error / Warning Alerts
                if (exceedsSpendable) ...[
                  const SizedBox(height: RootSpacing.md),
                  _SolidAlertBanner(
                    isDark: isDark,
                    type: _AlertType.warning,
                    message:
                        'This transfer exceeds your confirmed balance after fees. Reduce the amount or wait for pending funds to settle.',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: RootSpacing.md),
                  _SolidAlertBanner(
                    isDark: isDark,
                    type: _AlertType.error,
                    message: state.errorMessage!,
                  ),
                ],
              ],
            ),
          ),

          // 2. Fixed Floating Primary Action Button (Transparent Background)
          Positioned(
            left: context.pageHorizontalPadding,
            right: context.pageHorizontalPadding,
            bottom: buttonBottom,
            child: PrimaryButton(
              label: state.isPreviewing
                  ? 'Preparing review...'
                  : 'Review transfer',
              onPressed:
                  state.isSending || state.isPreviewing || !state.canReview
                  ? null
                  : () async {
                      final valid = await controller.prepareReview();
                      if (!valid || !context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushNamed(AppRoutes.reviewTransfer);
                    },
            ),
          ),
        ],
      ),
    );
  }

  void _showCoinSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Consumer(
              builder: (consumerContext, sheetRef, child) {
                final isDark =
                    Theme.of(consumerContext).brightness == Brightness.dark;
                final sheetBg = isDark
                    ? RootBrandColors.nightPine
                    : RootBrandColors.pureWhite;
                final sheetBorder = isDark
                    ? RootBrandColors.borderPine
                    : const Color(0xFFD7E3DC);
                final titleColor = isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine;

                final utxosAsync = sheetRef.watch(walletUtxosProvider);
                final lockedSet =
                    sheetRef.watch(lockedUtxosProvider).valueOrNull ?? {};
                final selectedSet = sheetRef.watch(selectedUtxosProvider);

                return Container(
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(RootRadius.lg),
                    ),
                    border: Border.all(color: sheetBorder, width: 1.0),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: RootSpacing.sm),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? RootBrandColors.slatePine
                              : const Color(0xFFD7E3DC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: RootSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RootSpacing.md,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customize Inputs',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextButton(
                              onPressed: () => sheetRef
                                  .read(selectedUtxosProvider.notifier)
                                  .clear(),
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  color: RootBrandColors.pineGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: sheetBorder, height: 1),
                      Expanded(
                        child: utxosAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: RootBrandColors.pineGreen,
                            ),
                          ),
                          error: (err, stack) => Center(
                            child: Text(
                              'Error loading UTXOs: $err',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.mutedSage
                                    : const Color(0xFF5E6F68),
                              ),
                            ),
                          ),
                          data: (utxos) {
                            final spendableUtxos = utxos.where((utxo) {
                              final outpoint =
                                  '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
                              return !lockedSet.contains(outpoint);
                            }).toList();

                            if (spendableUtxos.isEmpty) {
                              return Center(
                                child: Text(
                                  'No spendable UTXOs available.',
                                  style: TextStyle(
                                    color: isDark
                                        ? RootBrandColors.mutedSage
                                        : const Color(0xFF5E6F68),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                vertical: RootSpacing.xs,
                              ),
                              itemCount: spendableUtxos.length,
                              separatorBuilder: (_, __) => Divider(
                                color: sheetBorder.withValues(alpha: 0.5),
                                height: 1,
                              ),
                              itemBuilder: (itemContext, index) {
                                final utxo = spendableUtxos[index];
                                final outpointStr =
                                    '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
                                final isSelected = selectedSet.contains(
                                  outpointStr,
                                );
                                final sats = utxo.txout.value.toSat();

                                String addressStr = 'Unknown';
                                try {
                                  final bdkAddress = bdk.Address.fromScript(
                                    script: utxo.txout.scriptPubkey,
                                    network: bdk.Network.testnet,
                                  );
                                  addressStr = bdkAddress.toString();
                                } catch (_) {}

                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: RootBrandColors.pineGreen,
                                  checkColor: RootBrandColors.warmIvory,
                                  onChanged: (_) {
                                    HapticFeedback.lightImpact();
                                    sheetRef
                                        .read(selectedUtxosProvider.notifier)
                                        .toggleUtxo(outpointStr);
                                  },
                                  title: Text(
                                    AppFormatters.sats(sats),
                                    style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${AppFormatters.maskAddress(addressStr)}\n${AppFormatters.maskAddress(outpointStr)}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: isDark
                                            ? RootBrandColors.mutedSage
                                            : const Color(0xFF5E6F68),
                                      ),
                                    ),
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(RootSpacing.md),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pasteAddress(SendController controller) async {
    final clipboard = await Clipboard.getData('text/plain');
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    final sanitized = _sanitizeAddressText(text);
    controller.setAddress(sanitized);
    final updated = ref.read(sendControllerProvider);
    _addressController.text = updated.draft.address;
    if (_isSatsMode) {
      _amountController.text = updated.amountSats?.toString() ?? '';
    } else {
      _amountController.text = updated.draft.amountBtcText;
    }
  }

  String _sanitizeAddressText(String text) {
    if (text.isEmpty) return text;

    final hasCjk = text.runes.any(
      (rune) =>
          (rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0x3000 && rune <= 0x303F) ||
          (rune >= 0xFF00 && rune <= 0xFFEF),
    );

    if (!hasCjk) {
      return text;
    }

    try {
      final leBytes = <int>[];
      for (var i = 0; i < text.length; i++) {
        final codeUnit = text.codeUnitAt(i);
        leBytes.add(codeUnit & 0xFF);
        leBytes.add((codeUnit >> 8) & 0xFF);
      }
      final decodedLe = String.fromCharCodes(leBytes).trim();
      if (_looksLikeTestnetAddressOrUri(decodedLe)) {
        return decodedLe;
      }
    } catch (_) {}

    try {
      final beBytes = <int>[];
      for (var i = 0; i < text.length; i++) {
        final codeUnit = text.codeUnitAt(i);
        beBytes.add((codeUnit >> 8) & 0xFF);
        beBytes.add(codeUnit & 0xFF);
      }
      final decodedBe = String.fromCharCodes(beBytes).trim();
      if (_looksLikeTestnetAddressOrUri(decodedBe)) {
        return decodedBe;
      }
    } catch (_) {}

    return text;
  }

  bool _looksLikeTestnetAddressOrUri(String text) {
    final clean = text.toLowerCase().trim();
    if (clean.startsWith('bitcoin:')) {
      final addressPart = clean.substring(8).split('?').first;
      return _looksLikeRawTestnetAddress(addressPart);
    }
    return _looksLikeRawTestnetAddress(clean);
  }

  bool _looksLikeRawTestnetAddress(String text) {
    if (text.startsWith('tb1') && text.length >= 42 && text.length <= 62) {
      return true;
    }
    if ((text.startsWith('m') ||
            text.startsWith('n') ||
            text.startsWith('2')) &&
        text.length >= 26 &&
        text.length <= 35) {
      return true;
    }
    return false;
  }

  Future<void> _scanAddress(
    BuildContext context,
    SendController controller,
  ) async {
    final result = await Navigator.of(context).push<ScannedBtcUri>(
      MaterialPageRoute<ScannedBtcUri>(builder: (_) => const ScanAddressPage()),
    );
    if (!context.mounted || result == null) {
      return;
    }

    _addressController.text = result.address;
    controller.setAddress(result.address);

    final amountBtc = result.amountBtc;
    if (amountBtc != null) {
      final normalized = _normalizeBtcAmount(amountBtc);
      if (_isSatsMode) {
        _amountController.text =
            ((amountBtc * AppConstants.satoshisPerBitcoin).round()).toString();
      } else {
        _amountController.text = normalized;
      }
      controller.setAmountBtc(normalized);
    }
  }

  void _applyAmountSats(int sats, SendController controller) {
    final normalized = _normalizeBtcAmount(
      sats / AppConstants.satoshisPerBitcoin,
    );
    if (_isSatsMode) {
      _amountController.text = sats.toString();
    } else {
      _amountController.text = normalized;
    }
    controller.setAmountBtc(normalized);
  }

  String _normalizeBtcAmount(double value) {
    final fixed = value.toStringAsFixed(8);
    final trimmed = fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }
}

// ========================================================
// SECTION WIDGETS
// ========================================================

class _BalanceOverviewCard extends StatelessWidget {
  const _BalanceOverviewCard({
    required this.isDark,
    required this.spendableSats,
    required this.pendingSats,
    required this.isLoading,
  });

  final bool isDark;
  final int spendableSats;
  final int pendingSats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Spendable balance',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: RootSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16382C)
                      : const Color(0xFFE8F3EE),
                  borderRadius: BorderRadius.circular(RootRadius.pill),
                  border: Border.all(
                    color: RootBrandColors.pineGreen.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: RootBrandColors.pineGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'DEV Testnet',
                      style: TextStyle(
                        color: RootBrandColors.pineGreen,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.xs),
          if (isLoading)
            Text(
              'Loading balance...',
              style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            Text(
              AppFormatters.btcFromSats(spendableSats),
              style: TextStyle(
                color: titleColor,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${AppFormatters.sats(spendableSats)} confirmed',
              style: TextStyle(
                color: bodyColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (pendingSats > 0) ...[
            const SizedBox(height: RootSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RootSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D2823)
                    : const Color(0xFFF0F5F2),
                borderRadius: BorderRadius.circular(RootRadius.sm),
                border: Border.all(
                  color: isDark
                      ? RootBrandColors.borderPine
                      : const Color(0xFFD7E3DC),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pending funds: ${AppFormatters.btcFromSats(pendingSats)} (not yet spendable)',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.isDark,
    required this.controller,
    required this.hasAddress,
    required this.hasValidAddress,
    required this.looksLikeMainnet,
    required this.statusLabel,
    required this.onAddressChanged,
    required this.onPaste,
    required this.onScan,
  });

  final bool isDark;
  final TextEditingController controller;
  final bool hasAddress;
  final bool hasValidAddress;
  final bool looksLikeMainnet;
  final String statusLabel;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onPaste;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    final Color statusBg;
    final Color statusBorder;
    final Color statusTextColor;
    final IconData statusIcon;

    if (hasAddress && hasValidAddress) {
      statusBg = isDark ? const Color(0xFF16382C) : const Color(0xFFE8F3EE);
      statusBorder = RootBrandColors.pineGreen.withValues(alpha: 0.4);
      statusTextColor = isDark
          ? RootBrandColors.warmIvory
          : RootBrandColors.pineGreen;
      statusIcon = Icons.check_circle_rounded;
    } else if (looksLikeMainnet) {
      statusBg = const Color(0xFF332005);
      statusBorder = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      statusTextColor = const Color(0xFFFBBF24);
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusBg = isDark ? RootBrandColors.slatePine : const Color(0xFFF4F7F5);
      statusBorder = isDark
          ? RootBrandColors.borderPine
          : const Color(0xFFD7E3DC);
      statusTextColor = bodyColor;
      statusIcon = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recipient',
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Paste a testnet address or scan a QR code.',
            style: TextStyle(color: bodyColor, fontSize: 12.5),
          ),
          const SizedBox(height: RootSpacing.md),
          TextField(
            controller: controller,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              color: titleColor,
            ),
            decoration: InputDecoration(
              labelText: 'Destination address',
              hintText: 'tb1q...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Paste address',
                    onPressed: onPaste,
                    icon: const Icon(Icons.content_paste_rounded, size: 20),
                    color: RootBrandColors.pineGreen,
                  ),
                  IconButton(
                    tooltip: 'Scan QR',
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    color: RootBrandColors.pineGreen,
                  ),
                ],
              ),
            ),
            minLines: 2,
            maxLines: 3,
            onChanged: onAddressChanged,
          ),
          const SizedBox(height: RootSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: RootSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(RootRadius.md),
              border: Border.all(color: statusBorder, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 16, color: statusTextColor),
                const SizedBox(width: RootSpacing.xs),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.isDark,
    required this.controller,
    required this.isSatsMode,
    required this.state,
    required this.spendableSats,
    required this.estimatedNgn,
    required this.onToggleUnit,
    required this.onAmountChanged,
    required this.onApplyQuickPercent,
    required this.onApplyMax,
  });

  final bool isDark;
  final TextEditingController controller;
  final bool isSatsMode;
  final SendState state;
  final int spendableSats;
  final String estimatedNgn;
  final VoidCallback onToggleUnit;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<double> onApplyQuickPercent;
  final VoidCallback onApplyMax;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Amount',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: RootSpacing.xs),
              // Unit toggle button (BTC ⇄ sats)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleUnit,
                  borderRadius: BorderRadius.circular(RootRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16382C)
                          : const Color(0xFFE8F3EE),
                      borderRadius: BorderRadius.circular(RootRadius.pill),
                      border: Border.all(
                        color: RootBrandColors.pineGreen.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 15,
                          color: RootBrandColors.pineGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSatsMode ? 'Unit: SATS' : 'Unit: BTC',
                          style: const TextStyle(
                            color: RootBrandColors.pineGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Choose how much to send from confirmed balance.',
            style: TextStyle(color: bodyColor, fontSize: 12.5),
          ),
          const SizedBox(height: RootSpacing.md),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
            decoration: InputDecoration(
              labelText: isSatsMode ? 'Amount (Satoshis)' : 'Amount (BTC)',
              hintText: isSatsMode ? '10000' : '0.00010000',
              suffixText: isSatsMode ? 'sats' : 'BTC',
              suffixStyle: TextStyle(
                color: bodyColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: RootSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  estimatedNgn,
                  style: TextStyle(color: bodyColor, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.amountSats != null && state.amountSats! > 0) ...[
                const SizedBox(width: RootSpacing.xs),
                Flexible(
                  child: Text(
                    isSatsMode
                        ? AppFormatters.btcFromSats(state.amountSats!)
                        : AppFormatters.sats(state.amountSats!),
                    style: TextStyle(
                      color: RootBrandColors.pineGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: RootSpacing.sm),
          Wrap(
            spacing: RootSpacing.sm,
            runSpacing: RootSpacing.sm,
            children: [
              _QuickAmountButton(
                label: '25%',
                onTap: spendableSats <= 0
                    ? null
                    : () => onApplyQuickPercent(0.25),
                isDark: isDark,
              ),
              _QuickAmountButton(
                label: '50%',
                onTap: spendableSats <= 0
                    ? null
                    : () => onApplyQuickPercent(0.50),
                isDark: isDark,
              ),
              _QuickAmountButton(
                label: 'Max',
                onTap: spendableSats <= state.estimatedFeeSats
                    ? null
                    : onApplyMax,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoinSelectionCard extends ConsumerWidget {
  const _CoinSelectionCard({required this.isDark, required this.onOpenSheet});

  final bool isDark;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    final selectedUtxos = ref.watch(selectedUtxosProvider);
    final utxos = ref.watch(walletUtxosProvider).valueOrNull ?? [];

    int selectedSats = 0;
    for (final utxo in utxos) {
      final outpoint = '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
      if (selectedUtxos.contains(outpoint)) {
        selectedSats += utxo.txout.value.toSat();
      }
    }

    final isManual = selectedUtxos.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coin Selection',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose specific inputs or let the wallet auto-select.',
                      style: TextStyle(color: bodyColor, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RootSpacing.xs),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: onOpenSheet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.toll_rounded, size: 15),
                    const SizedBox(width: 4),
                    Text(isManual ? 'Edit' : 'Select'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(RootSpacing.sm),
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
              children: [
                Icon(
                  isManual ? Icons.tune_rounded : Icons.auto_mode_rounded,
                  size: 16,
                  color: RootBrandColors.pineGreen,
                ),
                const SizedBox(width: RootSpacing.xs),
                Expanded(
                  child: Text(
                    isManual
                        ? '${selectedUtxos.length} inputs manually selected (${AppFormatters.sats(selectedSats)})'
                        : 'Automatic selection active (excludes locked UTXOs)',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferSummaryCard extends StatelessWidget {
  const _TransferSummaryCard({
    required this.isDark,
    required this.state,
    required this.totalSats,
    required this.remainingSats,
  });

  final bool isDark;
  final SendState state;
  final int? totalSats;
  final int? remainingSats;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer summary',
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Review what leaves your wallet before final check.',
            style: TextStyle(color: bodyColor, fontSize: 12.5),
          ),
          const SizedBox(height: RootSpacing.md),
          _MetricRow(
            label: 'Amount',
            value: state.amountSats == null
                ? '—'
                : AppFormatters.btcFromSats(state.amountSats!),
            isDark: isDark,
          ),
          const SizedBox(height: RootSpacing.sm),
          _MetricRow(
            label: 'Estimated fee',
            value: AppFormatters.sats(state.estimatedFeeSats),
            isDark: isDark,
          ),
          const SizedBox(height: RootSpacing.sm),
          _MetricRow(
            label: 'Total debit',
            value: totalSats == null
                ? '—'
                : '${AppFormatters.btcFromSats(totalSats!)} (${AppFormatters.sats(totalSats!)})',
            emphasized: true,
            isDark: isDark,
          ),
          const SizedBox(height: RootSpacing.sm),
          _MetricRow(
            label: 'Remaining confirmed balance',
            value: remainingSats == null
                ? '—'
                : remainingSats! >= 0
                ? AppFormatters.btcFromSats(remainingSats!)
                : 'Insufficient balance',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final bool isDark;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: bodyColor, fontSize: 12.5)),
          const SizedBox(height: RootSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(
          horizontal: RootSpacing.md,
          vertical: RootSpacing.xs,
        ),
        side: BorderSide(color: borderColor),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: bodyColor, fontSize: 13)),
        ),
        const SizedBox(width: RootSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: titleColor,
              fontSize: emphasized ? 14.5 : 13.5,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

enum _AlertType { info, warning, error }

class _SolidAlertBanner extends StatelessWidget {
  const _SolidAlertBanner({
    required this.isDark,
    required this.type,
    required this.message,
    this.icon,
  });

  final bool isDark;
  final _AlertType type;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor, defaultIcon) = switch (type) {
      _AlertType.info => (
        isDark ? RootBrandColors.slatePine : const Color(0xFFEFF5F2),
        isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
        isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
        Icons.info_outline_rounded,
      ),
      _AlertType.warning => (
        isDark ? const Color(0xFF332005) : const Color(0xFFFEF3C7),
        const Color(0xFFF59E0B).withValues(alpha: 0.4),
        isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
        Icons.warning_amber_rounded,
      ),
      _AlertType.error => (
        isDark ? const Color(0xFF3B1515) : const Color(0xFFFEE2E2),
        const Color(0xFFEF4444).withValues(alpha: 0.4),
        isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
        Icons.error_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(RootRadius.md),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 18, color: textColor),
          const SizedBox(width: RootSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
