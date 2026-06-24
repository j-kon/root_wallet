import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';

class AnimatedSuccessCheck extends StatefulWidget {
  const AnimatedSuccessCheck({
    super.key,
    this.size = 80.0,
    this.strokeWidth = 5.0,
    this.color = AppColors.success,
    this.onCompleted,
  });

  final double size;
  final double strokeWidth;
  final Color color;
  final VoidCallback? onCompleted;

  @override
  State<AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<AnimatedSuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleAnimation;
  late final Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _circleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOutBack),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted?.call();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _SuccessCheckPainter(
        circleProgress: _circleAnimation,
        checkProgress: _checkAnimation,
        color: widget.color,
        strokeWidth: widget.strokeWidth,
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: Listenable.merge([circleProgress, checkProgress]));

  final Animation<double> circleProgress;
  final Animation<double> checkProgress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw the circle progress
    final circleAngle = 2 * 3.141592653589793 * circleProgress.value;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      circleAngle,
      false,
      paint,
    );

    if (checkProgress.value > 0) {
      final path = Path();
      // Starting point: 27% of width, 50% of height
      final startPoint = Offset(size.width * 0.27, size.height * 0.50);
      // Mid point (bottom curve): 45% of width, 68% of height
      final midPoint = Offset(size.width * 0.45, size.height * 0.68);
      // End point: 73% of width, 36% of height
      final endPoint = Offset(size.width * 0.73, size.height * 0.36);

      path.moveTo(startPoint.dx, startPoint.dy);

      // Interpolate checkmark path
      if (checkProgress.value < 0.4) {
        final localVal = checkProgress.value / 0.4;
        final x = lerpDouble(startPoint.dx, midPoint.dx, localVal)!;
        final y = lerpDouble(startPoint.dy, midPoint.dy, localVal)!;
        path.lineTo(x, y);
      } else {
        path.lineTo(midPoint.dx, midPoint.dy);
        final localVal = (checkProgress.value - 0.4) / 0.6;
        final x = lerpDouble(midPoint.dx, endPoint.dx, localVal)!;
        final y = lerpDouble(midPoint.dy, endPoint.dy, localVal)!;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
