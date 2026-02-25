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
    final form = ref.read(sendFormProvider);
    _addressController = TextEditingController(text: form.address);
    _amountController = TextEditingController(text: form.amountBtcText);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendFormProvider);
    final notifier = ref.read(sendFormProvider.notifier);
    final btcNgnRate = ref.watch(btcNgnRateProvider);

    final estimatedNgn = btcNgnRate.when(
      data: (rate) {
        final amountBtc = state.amountBtc;
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
                        notifier.setAddress(text);
                      },
                      icon: const Icon(Icons.content_paste_rounded),
                    ),
                    IconButton(
                      tooltip: 'Scan QR',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('QR scan coming soon.')),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
              ),
              onChanged: notifier.setAddress,
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
              onChanged: notifier.setAmountBtc,
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
              label: state.isSubmitting ? 'Preparing...' : 'Review transfer',
              onPressed: state.isSubmitting || !state.canSubmit
                  ? null
                  : () async {
                      final ok = await notifier.buildTransaction();
                      if (!ok || !context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushNamed(AppRoutes.confirmSend);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
