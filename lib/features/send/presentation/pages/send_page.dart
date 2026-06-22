import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/send/presentation/models/scanned_btc_uri.dart';
import 'package:root_wallet/features/send/presentation/pages/scan_address_page.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/send/presentation/widgets/fee_selector.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class SendPage extends ConsumerStatefulWidget {
  const SendPage({super.key});

  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  late final TextEditingController _addressController;
  late final TextEditingController _amountController;

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

  @override
  Widget build(BuildContext context) {
    final surfaceRaised = AppColors.surfaceRaisedOf(context);
    final border = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
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
        if (amountBtc == null) {
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

    return AppScaffold(
      title: 'Send BTC',
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
                      alpha: AppColors.isDark(context) ? 0.58 : 0.92,
                    ),
                    highlightOpacity: 0.05,
                    padding: EdgeInsets.all(
                      context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: const [
                            _StageChip(
                              icon: Icons.looks_one_rounded,
                              label: 'Recipient',
                            ),
                            _StageChip(
                              icon: Icons.looks_two_rounded,
                              label: 'Amount',
                            ),
                            _StageChip(
                              icon: Icons.looks_3_rounded,
                              label: 'Fee',
                            ),
                            _StageChip(
                              icon: Icons.looks_4_rounded,
                              label: 'Review',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Move funds with more confidence.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                fontSize: context.isVeryCompactWidth
                                    ? 20
                                    : context.isCompactWidth
                                    ? 22
                                    : 24,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Confirm the address, choose an amount, and review fee impact before broadcasting.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Recipient',
                    subtitle: 'Paste a testnet address or scan a QR code.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _addressController,
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              final sanitized = _sanitizeAddressText(newValue.text);
                              if (sanitized != newValue.text) {
                                return TextEditingValue(
                                  text: sanitized,
                                  selection: TextSelection.collapsed(offset: sanitized.length),
                                );
                              }
                              return newValue;
                            }),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Destination address',
                            hintText: 'tb1...',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Paste address',
                                  onPressed: () => _pasteAddress(controller),
                                  icon: const Icon(Icons.content_paste_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Scan QR',
                                  onPressed: () =>
                                      _scanAddress(context, controller),
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          minLines: 2,
                          maxLines: 3,
                          onChanged: controller.setAddress,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: hasAddress && state.draft.hasValidAddress
                                ? AppColors.success.withValues(alpha: 0.10)
                                : state.draft.looksLikeMainnetAddress
                                ? AppColors.warning.withValues(alpha: 0.10)
                                : surfaceRaised,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: hasAddress && state.draft.hasValidAddress
                                  ? AppColors.success.withValues(alpha: 0.22)
                                  : state.draft.looksLikeMainnetAddress
                                  ? AppColors.warning.withValues(alpha: 0.22)
                                  : border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasAddress && state.draft.hasValidAddress
                                    ? Icons.verified_rounded
                                    : state.draft.looksLikeMainnetAddress
                                    ? Icons.warning_amber_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: hasAddress && state.draft.hasValidAddress
                                    ? AppColors.success
                                    : state.draft.looksLikeMainnetAddress
                                    ? AppColors.warning
                                    : textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  addressStatusLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Amount',
                    subtitle: 'Choose how much to send from confirmed balance.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (BTC)',
                            hintText: '0.00010000',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: controller.setAmountBtc,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          estimatedNgn,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _QuickAmountButton(
                              label: '25%',
                              onTap: spendableSats <= 0
                                  ? null
                                  : () => _applyAmountSats(
                                      ((spendableSats * 0.25).floor())
                                          .clamp(0, spendableSats)
                                          .toInt(),
                                      controller,
                                    ),
                            ),
                            _QuickAmountButton(
                              label: '50%',
                              onTap: spendableSats <= 0
                                  ? null
                                  : () => _applyAmountSats(
                                      ((spendableSats * 0.5).floor())
                                          .clamp(0, spendableSats)
                                          .toInt(),
                                      controller,
                                    ),
                            ),
                            _QuickAmountButton(
                              label: 'Max',
                              onTap: spendableSats <= state.estimatedFeeSats
                                  ? null
                                  : () => _applyAmountSats(
                                      spendableSats - state.estimatedFeeSats,
                                      controller,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _MetricRow(
                          label: 'Spendable balance',
                          value: balance == null
                              ? 'Loading...'
                              : AppFormatters.btcFromSats(spendableSats),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _MetricRow(
                          label: 'Estimated network fee',
                          value: AppFormatters.sats(state.estimatedFeeSats),
                        ),
                        if (pendingSats > 0) ...[
                          const SizedBox(height: AppSpacing.sm),
                          InfoBanner(
                            type: InfoBannerType.info,
                            message:
                                'Pending funds: ${AppFormatters.btcFromSats(pendingSats)}. They may not be spendable yet.',
                            icon: Icons.timelapse_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _FormSection(
                    title: 'Network fee',
                    subtitle:
                        'Choose the balance between confirmation urgency and cost.',
                    child: FeeSelector(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Coin Selection',
                    subtitle: 'Choose specific inputs or let the wallet auto-select.',
                    child: Builder(
                      builder: (builderContext) {
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

                        return Column(
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
                                        isManual
                                            ? 'Manual selection'
                                            : 'Automatic selection',
                                        style: Theme.of(builderContext).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isManual
                                            ? '${selectedUtxos.length} inputs selected (${AppFormatters.sats(selectedSats)})'
                                            : 'Excluded locked UTXOs automatically.',
                                        style: Theme.of(builderContext).textTheme.bodySmall?.copyWith(
                                              color: textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showCoinSelectionSheet(builderContext),
                                  icon: const Icon(Icons.toll_rounded, size: 16),
                                  label: Text(isManual ? 'Edit' : 'Select'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSection(
                    title: 'Transfer summary',
                    subtitle:
                        'Review what leaves your wallet before final check.',
                    child: Column(
                      children: [
                        _MetricRow(
                          label: 'Amount',
                          value: state.amountSats == null
                              ? '—'
                              : AppFormatters.btcFromSats(state.amountSats!),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetricRow(
                          label: 'Estimated fee',
                          value: AppFormatters.sats(state.estimatedFeeSats),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetricRow(
                          label: 'Total debit',
                          value: totalSats == null
                              ? '—'
                              : '${AppFormatters.btcFromSats(totalSats)} (${AppFormatters.sats(totalSats)})',
                          emphasized: true,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetricRow(
                          label: 'Remaining confirmed balance',
                          value: remainingSats == null
                              ? '—'
                              : remainingSats >= 0
                              ? AppFormatters.btcFromSats(remainingSats)
                              : 'Insufficient balance',
                        ),
                      ],
                    ),
                  ),
                  if (exceedsSpendable) ...[
                    const SizedBox(height: AppSpacing.md),
                    const InfoBanner(
                      type: InfoBannerType.warning,
                      message:
                          'This transfer exceeds your confirmed balance after fees. Reduce the amount or wait for pending funds to settle.',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
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
            SizedBox(height: context.navBarButtonSpacing),
          ],
        ),
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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Consumer(
              builder: (consumerContext, ref, child) {
                final utxosAsync = ref.watch(walletUtxosProvider);
                final lockedSet = ref.watch(lockedUtxosProvider).valueOrNull ?? {};
                final selectedSet = ref.watch(selectedUtxosProvider);

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(consumerContext).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customize Inputs',
                              style: Theme.of(consumerContext).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => ref.read(selectedUtxosProvider.notifier).clear(),
                              child: const Text('Clear all'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: utxosAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Center(child: Text('Error loading UTXOs: $err')),
                          data: (utxos) {
                            final spendableUtxos = utxos.where((utxo) {
                              final outpoint = '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
                              return !lockedSet.contains(outpoint);
                            }).toList();

                            if (spendableUtxos.isEmpty) {
                              return const Center(child: Text('No spendable UTXOs available.'));
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: spendableUtxos.length,
                              itemBuilder: (itemContext, index) {
                                final utxo = spendableUtxos[index];
                                final outpointStr = '${utxo.outpoint.txid.toString()}:${utxo.outpoint.vout}';
                                final isSelected = selectedSet.contains(outpointStr);
                                final sats = utxo.txout.value.toSat();

                                String addressStr = 'Unknown';
                                try {
                                  final address = bdk.Address.fromScript(
                                    script: utxo.txout.scriptPubkey,
                                    network: bdk.Network.testnet,
                                  );
                                  addressStr = address.toString();
                                } catch (_) {}

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (_) {
                                    HapticFeedback.lightImpact();
                                    ref.read(selectedUtxosProvider.notifier).toggleUtxo(outpointStr);
                                  },
                                  title: Text(
                                    AppFormatters.sats(sats),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${AppFormatters.maskAddress(addressStr)}\n${AppFormatters.maskAddress(outpointStr)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
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
    _amountController.text = updated.draft.amountBtcText;
  }

  String _sanitizeAddressText(String text) {
    if (text.isEmpty) return text;

    // Check if the text contains CJK (Chinese, Japanese, Korean) characters
    final hasCjk = text.runes.any((rune) =>
        (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x3000 && rune <= 0x303F) ||
        (rune >= 0xFF00 && rune <= 0xFFEF)
    );

    if (!hasCjk) {
      return text;
    }

    // Try decoding as UTF-16 Little Endian (bytes stored in code units)
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

    // Try decoding as UTF-16 Big Endian
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
    if ((text.startsWith('m') || text.startsWith('n') || text.startsWith('2')) && text.length >= 26 && text.length <= 35) {
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
      _amountController.text = normalized;
      controller.setAmountBtc(normalized);
    }
  }

  void _applyAmountSats(int sats, SendController controller) {
    final normalized = _normalizeBtcAmount(
      sats / AppConstants.satoshisPerBitcoin,
    );
    _amountController.text = normalized;
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

class _FormSection extends StatelessWidget {
  const _FormSection({
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
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.94),
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

class _StageChip extends StatelessWidget {
  const _StageChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.84),
      highlightOpacity: 0.04,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      child: Text(label),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
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
