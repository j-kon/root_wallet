import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/send/presentation/models/scanned_btc_uri.dart';
import 'package:root_wallet/features/send/presentation/pages/scan_address_page.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/send/presentation/widgets/fee_selector.dart';

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
    final state = ref.watch(sendControllerProvider);
    final controller = ref.read(sendControllerProvider.notifier);
    final btcNgnRate = ref.watch(btcNgnRateProvider);

    final estimatedNgn = btcNgnRate.when(
      data: (rate) {
        final amountBtc = state.draft.amountBtc;
        if (amountBtc == null) {
          return 'Enter BTC amount to estimate NGN';
        }
        return 'Approx. ${AppFormatters.ngn(amountBtc * rate.value)}';
      },
      loading: () => 'Loading FX rate...',
      error: (_, _) => 'Approx. NGN -- (TODO: rate)',
    );

    return AppScaffold(
      title: 'Send BTC',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Destination address',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Paste address',
                      onPressed: () async {
                        final clipboard = await Clipboard.getData('text/plain');
                        final text = clipboard?.text?.trim();
                        if (text == null || text.isEmpty) {
                          return;
                        }

                        _addressController.text = text;
                        controller.setAddress(text);
                      },
                      icon: const Icon(Icons.content_paste_rounded),
                    ),
                    IconButton(
                      tooltip: 'Scan QR',
                      onPressed: () async {
                        final result = await Navigator.of(context).push<
                          ScannedBtcUri
                        >(
                          MaterialPageRoute<ScannedBtcUri>(
                            builder: (_) => const ScanAddressPage(),
                          ),
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
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
              ),
              onChanged: controller.setAddress,
            ),
            const SizedBox(height: AppSpacing.md),
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
            Text(estimatedNgn, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            const FeeSelector(),
            const SizedBox(height: AppSpacing.md),
            if (state.errorMessage != null)
              InfoBanner(
                type: InfoBannerType.error,
                message: state.errorMessage!,
              ),
            const Spacer(),
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
          ],
        ),
      ),
    );
  }

  String _normalizeBtcAmount(double value) {
    final fixed = value.toStringAsFixed(8);
    final trimmed = fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }
}
