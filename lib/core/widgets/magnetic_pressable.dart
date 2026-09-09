import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tactile micro-interaction wrapper providing magnetic spring-like press depth
/// and haptic feedback to interactive elements.
class MagneticPressable extends StatefulWidget {
  const MagneticPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.975,
    this.duration = const Duration(milliseconds: 140),
    this.enableHaptics = true,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;
  final bool enableHaptics;
  final MouseCursor cursor;

  @override
  State<MagneticPressable> createState() => _MagneticPressableState();
}

class _MagneticPressableState extends State<MagneticPressable> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    final child = AnimatedScale(
      scale: (!disableAnimations && _isPressed) ? widget.pressedScale : 1.0,
      duration: widget.duration,
      curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.child,
    );

    if (!isInteractive) {
      return child;
    }

    return MouseRegion(
      cursor: widget.cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}
