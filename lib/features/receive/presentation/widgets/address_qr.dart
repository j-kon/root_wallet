import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Address QR code widget adhering to Root Wallet Brand Guidelines.
/// Features a solid-surface, high-contrast canvas with dynamic viewfinder corner
/// brackets, ambient breathing focus framing, and magnetic tap interaction.
class AddressQr extends StatefulWidget {
  const AddressQr({
    super.key,
    required this.address,
    this.payload,
    this.requestedAmountBtc,
    this.onTap,
  });

  final String address;
  final String? payload;
  final double? requestedAmountBtc;
  final VoidCallback? onTap;

  @override
  State<AddressQr> createState() => _AddressQrState();
}

class _AddressQrState extends State<AddressQr>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 0.85).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pulseController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final cardBg =
        isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite;
    final cardBorder =
        isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC);
    final qrPayload = widget.payload ?? 'bitcoin:${widget.address}';
    const qrInk = Color(0xFF101917); // Root brand Charcoal Pine for deep contrast

    final qrSize = context.isVeryCompactWidth
        ? 170.0
        : context.isCompactWidth
            ? 190.0
            : 210.0;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
          MagneticPressable(
            onTap: () {
              _triggerPulse();
              if (widget.onTap != null) {
                widget.onTap!();
              } else {
                Clipboard.setData(ClipboardData(text: qrPayload));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment request copied to clipboard.'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final pulseOpacity =
                    disableAnimations ? 0.75 : _pulseAnimation.value;

                return CustomPaint(
                  foregroundPainter: _ViewfinderCornersPainter(
                    bracketColor: RootBrandColors.pineGreen.withValues(
                      alpha: pulseOpacity,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4.0),
                    padding: const EdgeInsets.all(RootSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2A3F39)
                            : const Color(0xFFE2EBE6),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.25 : 0.04,
                          ),
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
                );
              },
            ),
          ),
          const SizedBox(height: RootSpacing.xs),
          Text(
            'Tap QR code to copy payment request',
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.requestedAmountBtc != null &&
              widget.requestedAmountBtc! > 0) ...[
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
                    '${widget.requestedAmountBtc!.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} BTC requested',
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

/// Custom painter that draws precision viewfinder corner reticles around the QR canvas.
class _ViewfinderCornersPainter extends CustomPainter {
  const _ViewfinderCornersPainter({required this.bracketColor});

  final Color bracketColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bracketColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const armLength = 12.0;
    const inset = 0.0;

    // Top-left
    canvas.drawLine(
      const Offset(inset, inset + armLength),
      const Offset(inset, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + armLength, inset),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - inset - armLength, inset),
      Offset(size.width - inset, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + armLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(inset, size.height - inset - armLength),
      Offset(inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + armLength, size.height - inset),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - inset - armLength, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - armLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderCornersPainter oldDelegate) {
    return oldDelegate.bracketColor != bracketColor;
  }
}
