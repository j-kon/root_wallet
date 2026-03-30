import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class AddressQr extends StatelessWidget {
  const AddressQr({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final qrPayload = 'bitcoin:$address';
    final surface = AppColors.surfaceOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: context.isCompactWidth ? 208 : 220,
                    backgroundColor: surface,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: textPrimary,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: textPrimary,
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
      ),
    );
  }
}
