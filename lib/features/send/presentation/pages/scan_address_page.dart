import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/features/send/presentation/models/bitcoin_uri_parser.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

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
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              tint: AppColors.glassSurfaceStrongOf(
                context,
              ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.95),
              highlightOpacity: 0.05,
              padding: EdgeInsets.all(
                context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -34,
                    right: -20,
                    child: _ScanOrb(
                      size: 136,
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -34,
                    child: _ScanOrb(
                      size: 108,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ScanBadge(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'QR scan ready',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Scan a Bitcoin address or BIP-21 QR code.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Point the camera at a testnet4 payment QR and we will fill the send form for review.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: GlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                tint: AppColors.glassSurfaceOf(
                  context,
                ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
                highlightOpacity: 0.05,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
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
                            IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const InfoBanner(
                      type: InfoBannerType.info,
                      message:
                          'Supported formats: raw testnet4 address and bitcoin: URI payment requests.',
                      icon: Icons.info_outline_rounded,
                    ),
                  ],
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

class _ScanBadge extends StatelessWidget {
  const _ScanBadge({required this.icon, required this.label});

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

class _ScanOrb extends StatelessWidget {
  const _ScanOrb({required this.size, required this.color});

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
