import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';

class SwipeToConfirmSlider extends StatefulWidget {
  const SwipeToConfirmSlider({
    super.key,
    required this.onConfirm,
    required this.label,
    this.enabled = true,
  });

  final VoidCallback onConfirm;
  final String label;
  final bool enabled;

  @override
  State<SwipeToConfirmSlider> createState() => _SwipeToConfirmSliderState();
}

class _SwipeToConfirmSliderState extends State<SwipeToConfirmSlider> with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  late final AnimationController _resetController;
  late final Animation<double> _resetAnimation;
  bool _confirmed = false;
  double _lastDragFeedbackPercent = 0.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDragWidth) {
    if (!widget.enabled || _confirmed) return;

    if (_resetController.isAnimating) {
      _resetController.stop();
    }

    final newDragValue = (_dragValue + details.delta.dx).clamp(0.0, maxDragWidth);
    final dragPercent = maxDragWidth > 0 ? newDragValue / maxDragWidth : 0.0;

    // Trigger subtle haptics along the drag path
    if ((dragPercent - _lastDragFeedbackPercent).abs() >= 0.15) {
      HapticFeedback.selectionClick();
      _lastDragFeedbackPercent = (dragPercent / 0.15).round() * 0.15;
    }

    setState(() {
      _dragValue = newDragValue;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDragWidth) {
    if (!widget.enabled || _confirmed) return;

    final dragPercent = maxDragWidth > 0 ? _dragValue / maxDragWidth : 0.0;

    if (dragPercent >= 0.90) {
      // Confirmed!
      HapticFeedback.mediumImpact();
      setState(() {
        _dragValue = maxDragWidth;
        _confirmed = true;
      });
      widget.onConfirm();
    } else {
      // Snap back
      _resetAnimation = Tween<double>(begin: _dragValue, end: 0.0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
      )..addListener(() {
          setState(() {
            _dragValue = _resetAnimation.value;
          });
        });
      _lastDragFeedbackPercent = 0.0;
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppColors.isDark(context);
    final handleSize = 54.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxDragWidth = totalWidth - handleSize - 8.0; // 4px padding on each side

        final dragPercent = maxDragWidth > 0 ? _dragValue / maxDragWidth : 0.0;

        return Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: Container(
            height: 62,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _confirmed
                    ? AppColors.success.withValues(alpha: 0.4)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.secondary.withValues(alpha: 0.14),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg - 1),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Track Background Color
                  Positioned.fill(
                    child: Container(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.shade100,
                    ),
                  ),
                  
                  // Fill Background Color (Green gradient matching confirmed state)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _dragValue + (handleSize / 2) + 4.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2 + (dragPercent * 0.4)),
                            AppColors.success.withValues(alpha: dragPercent * 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Text Label (dims as you drag)
                  Opacity(
                    opacity: math.max(0.0, 1.0 - (dragPercent * 2.0)),
                    child: Text(
                      widget.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                  // Drag Target Handle
                  Positioned(
                    left: 4.0 + _dragValue,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) =>
                          _onHorizontalDragUpdate(details, maxDragWidth),
                      onHorizontalDragEnd: (details) =>
                          _onHorizontalDragEnd(details, maxDragWidth),
                      child: Container(
                        width: handleSize,
                        height: handleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _confirmed
                              ? AppColors.success
                              : theme.colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _confirmed
                              ? Icons.check_rounded
                              : Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
