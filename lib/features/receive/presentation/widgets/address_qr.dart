import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class AddressQr extends StatelessWidget {
  const AddressQr({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final qrPayload = 'bitcoin:$address';
    const qrInk = AppColors.textPrimary;
    final outline = AppColors.borderOf(context);

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: outline),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: context.isCompactWidth ? 208 : 220,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: qrInk,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrInk,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppFormatters.maskAddress(address),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
