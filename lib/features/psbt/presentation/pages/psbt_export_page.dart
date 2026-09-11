import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';

class PsbtExportArgs {
  const PsbtExportArgs({
    required this.psbtBase64,
    required this.isSigned,
    this.txid,
  });

  final String psbtBase64;
  final bool isSigned;
  final String? txid;
}

class PsbtExportPage extends StatelessWidget {
  const PsbtExportPage({
    super.key,
    required this.args,
  });

  final PsbtExportArgs args;

  Future<void> _copyToClipboard(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: args.psbtBase64));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            args.isSigned
                ? 'Signed PSBT copied to clipboard.'
                : 'Unsigned PSBT copied to clipboard.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: args.isSigned ? 'Signed PSBT' : 'Unsigned PSBT',
      body: ListView(
        padding: const EdgeInsets.all(RootSpacing.lg),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                args.isSigned ? 'Signed Transaction' : 'Unsigned Transaction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: args.isSigned
                      ? RootBrandColors.pineGreen.withValues(alpha: 0.15)
                      : RootBrandColors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(RootRadius.sm),
                  border: Border.all(
                    color: args.isSigned
                        ? RootBrandColors.pineGreen
                        : RootBrandColors.amberAccent,
                  ),
                ),
                child: Text(
                  args.isSigned ? 'SIGNED' : 'UNSIGNED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: args.isSigned
                        ? RootBrandColors.pineGreen
                        : RootBrandColors.amberAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.xs),
          Text(
            args.isSigned
                ? 'This transaction is signed and ready for broadcast or air-gapped transmission.'
                : 'Export this transaction to a signing device (e.g. cold storage or coordinator) to sign.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
            ),
          ),
          const SizedBox(height: RootSpacing.lg),
          Center(
            child: Container(
              padding: const EdgeInsets.all(RootSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(RootRadius.lg),
                border: Border.all(
                  color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                  width: 1.5,
                ),
              ),
              child: QrImageView(
                data: args.psbtBase64,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: RootBrandColors.charcoalPine,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: RootBrandColors.charcoalPine,
                ),
              ),
            ),
          ),
          const SizedBox(height: RootSpacing.lg),
          MagneticPressable(
            onTap: () => _copyToClipboard(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: RootSpacing.md,
                horizontal: RootSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: RootBrandColors.pineGreen,
                borderRadius: BorderRadius.circular(RootRadius.md),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy, color: RootBrandColors.warmIvory, size: 20),
                  SizedBox(width: RootSpacing.sm),
                  Text(
                    'Copy PSBT (Base64)',
                    style: TextStyle(
                      color: RootBrandColors.warmIvory,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RootSpacing.lg),
          Text(
            'Raw Base64 PSBT Payload',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
            ),
          ),
          const SizedBox(height: RootSpacing.xs),
          Container(
            padding: const EdgeInsets.all(RootSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
              borderRadius: BorderRadius.circular(RootRadius.md),
              border: Border.all(
                color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
              ),
            ),
            child: SelectableText(
              args.psbtBase64,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: isDark ? RootBrandColors.mutedSage : RootBrandColors.charcoalPine,
              ),
              maxLines: 6,
            ),
          ),
          if (args.txid != null && args.txid!.isNotEmpty) ...[
            const SizedBox(height: RootSpacing.md),
            Row(
              children: [
                Text(
                  'TxID: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
                  ),
                ),
                Expanded(
                  child: Text(
                    args.txid!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: args.txid!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('TxID copied.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
