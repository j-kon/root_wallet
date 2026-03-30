import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
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
    final surface = AppColors.surfaceOf(context);
    final surfaceRaised = AppColors.surfaceRaisedOf(context);
    final border = AppColors.borderOf(context);
    final shadow = AppColors.shadowOf(context);
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
      error: (_, _) => 'FX rate temporarily unavailable.',
    );
    final address = state.draft.address.trim();
    final hasAddress = address.isNotEmpty;
    final addressStatusLabel = !hasAddress
        ? 'No address entered yet'
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
                  Container(
                    padding: EdgeInsets.all(
                      context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: shadow,
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
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
                                fontSize: context.isCompactWidth ? 22 : 24,
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
                                : surfaceRaised,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: hasAddress && state.draft.hasValidAddress
                                  ? AppColors.success.withValues(alpha: 0.22)
                                  : border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasAddress && state.draft.hasValidAddress
                                    ? Icons.verified_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: hasAddress && state.draft.hasValidAddress
                                    ? AppColors.success
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: textSecondary),
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
              label: 'Review transfer',
              onPressed: state.isSending || !state.canReview
                  ? null
                  : () {
                      final valid = controller.validateForReview();
                      if (!valid || !context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushNamed(AppRoutes.reviewTransfer);
                    },
            ),
            SizedBox(height: context.navBarBottomSpacing),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteAddress(SendController controller) async {
    final clipboard = await Clipboard.getData('text/plain');
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    _addressController.text = text;
    controller.setAddress(text);
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
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final shadow = AppColors.shadowOf(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: AppColors.isDark(context) ? 0.94 : 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 18,
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

class _StageChip extends StatelessWidget {
  const _StageChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaceRaised = AppColors.surfaceRaisedOf(context);
    final border = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border),
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
