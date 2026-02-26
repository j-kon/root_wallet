import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/features/send/presentation/models/bitcoin_uri_parser.dart';

class ScanAddressPage extends StatefulWidget {
  const ScanAddressPage({super.key});

  @override
  State<ScanAddressPage> createState() => _ScanAddressPageState();
}

class _ScanAddressPageState extends State<ScanAddressPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Scan address',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan a Bitcoin address or BIP-21 QR code.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_hasResult) {
                      return;
                    }

                    final raw = _firstRawValue(capture);
                    if (raw == null) {
                      return;
                    }

                    final parsed = BitcoinUriParser.parse(raw);
                    if (parsed == null) {
                      return;
                    }

                    _hasResult = true;
                    Navigator.of(context).pop(parsed);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _firstRawValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        return raw;
      }
    }
    return null;
  }
}
