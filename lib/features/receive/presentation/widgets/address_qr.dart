import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Address QR code widget adhering to Root Wallet Brand Guidelines.
/// Features a solid-surface, high-contrast canvas with 1px border.
class AddressQr extends StatelessWidget {
  const AddressQr({
    super.key,
    required this.address,
    this.payload,
    this.requestedAmountBtc,
  });

  final String address;
  final String? payload;
  final double? requestedAmountBtc;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final cardBg =
        isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite;
    final cardBorder =
        isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC);
    final qrPayload = payload ?? 'bitcoin:$address';
    const qrInk = Color(0xFF101917); // Root brand Charcoal Pine for deep contrast

    final qrSize = context.isVeryCompactWidth
        ? 170.0
        : context.isCompactWidth
            ? 190.0
            : 210.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: RootSpacing.md,
        vertical: RootSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(RootSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(RootRadius.md),
              border: Border.all(
                color: isDark ? const Color(0xFF2A3F39) : const Color(0xFFE2EBE6),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: qrSize,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: qrInk,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: qrInk,
              ),
            ),
          ),
          if (requestedAmountBtc != null && requestedAmountBtc! > 0) ...[
            const SizedBox(height: RootSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RootSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? RootBrandColors.deepForest
                    : const Color(0xFFE8F6F1),
                borderRadius: BorderRadius.circular(RootRadius.pill),
                border: Border.all(
                  color: RootBrandColors.pineGreen.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    size: 13,
                    color: RootBrandColors.pineGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${requestedAmountBtc!.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} BTC requested',
                    style: const TextStyle(
                      color: RootBrandColors.pineGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
