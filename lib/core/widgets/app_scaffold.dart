import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.backgroundOf(context);
    final backgroundTint = AppColors.backgroundTintOf(context);
    final glow = AppColors.glassGlowOf(context);
    final highlight = AppColors.glassHighlightOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [background, backgroundTint, background],
              stops: const [0, 0.42, 1],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -60,
          child: _AmbientOrb(size: 240, color: glow.withValues(alpha: 0.28)),
        ),
        Positioned(
          top: 120,
          left: -70,
          child: _AmbientOrb(
            size: 220,
            color: highlight.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -120,
          right: -20,
          child: _AmbientOrb(
            size: 280,
            color: AppColors.primary.withValues(alpha: 0.10),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: title == null
              ? null
              : AppBar(title: Text(title!), actions: actions),
          body: SafeArea(child: body),
          floatingActionButton: floatingActionButton,
        ),
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

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
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: size * 0.28,
              spreadRadius: AppSpacing.xs,
            ),
          ],
        ),
      ),
    );
  }
}
