import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.btcAmount,
    required this.fiatAmountLabel,
    this.subtitle = 'Available balance',
    this.onTap,
  });

  final String subtitle;
  final String btcAmount;
  final String fiatAmountLabel;
  final VoidCallback? onTap;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _glowController.repeat();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handlePointerMove(PointerEvent event) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final localPos = box.globalToLocal(event.position);
    final center = Offset(box.size.width / 2, box.size.height / 2);
    setState(() {
      _tilt = Offset(
        ((localPos.dx - center.dx) / center.dx).clamp(-1.0, 1.0),
        ((localPos.dy - center.dy) / center.dy).clamp(-1.0, 1.0),
      );
    });
  }

  void _handlePointerUp(PointerEvent event) {
    setState(() {
      _tilt = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactWidth;

    return Listener(
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          blur: 30,
          tint: AppColors.glassSurfaceStrongOf(context).withValues(
            alpha: AppColors.isDark(context) ? 0.58 : 0.74,
          ),
          borderColor: AppColors.glassBorderOf(context),
          shadowColor: AppColors.glassGlowOf(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      final Alignment beginAlignment;
                      final Alignment endAlignment;
                      if (Platform.environment.containsKey('FLUTTER_TEST')) {
                        beginAlignment = Alignment.topLeft;
                        endAlignment = Alignment.bottomRight;
                      } else {
                        final angle = _glowController.value * 2 * math.pi;
                        beginAlignment = Alignment(
                          math.cos(angle) + _tilt.dx * 0.25,
                          math.sin(angle) + _tilt.dy * 0.25,
                        );
                        endAlignment = Alignment(
                          math.cos(angle + math.pi) + _tilt.dx * 0.25,
                          math.sin(angle + math.pi) + _tilt.dy * 0.25,
                        );
                      }

                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: beginAlignment,
                            end: endAlignment,
                            colors: const <Color>[
                              AppColors.secondary,
                              AppColors.primaryDeep,
                              AppColors.primary,
                            ],
                            stops: const <double>[0, 0.55, 1],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: -34 + (_tilt.dy * 16),
                  right: -18 - (_tilt.dx * 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: 142,
                    height: 142,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -72 + (_tilt.dy * 20),
                  left: -16 + (_tilt.dx * 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: 154,
                    height: 154,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(
                    isCompact ? AppSpacing.md : AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Icon(
                              Icons.currency_bitcoin_rounded,
                              color: AppColors.accent,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'Self-custody',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),
                      Text(
                        widget.subtitle.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.btcAmount,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: isCompact ? 34 : 40,
                                letterSpacing: -1.4,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Protected locally, ready when you are.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _BalanceMetaChip(
                            icon: Icons.show_chart_rounded,
                            label: widget.fiatAmountLabel,
                          ),
                          const _BalanceMetaChip(
                            icon: Icons.lock_outline_rounded,
                            label: 'Keys on-device',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _BalanceMetaChip extends StatelessWidget {
  const _BalanceMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 220.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: context.isVeryCompactWidth ? 11.5 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
