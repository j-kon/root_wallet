import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/features/receive/presentation/pages/receive_page.dart';
import 'package:root_wallet/features/send/presentation/pages/send_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/settings_page.dart';
import 'package:root_wallet/features/transactions/presentation/pages/transactions_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/wallet_home_page.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late int _fromIndex;
  late int _toIndex;

  late double _startFractionalCenter;

  late final AnimationController _controller;

  static const _destinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    _ShellDestination(
      label: 'Receive',
      icon: Icons.call_received_rounded,
      activeIcon: Icons.call_received_rounded,
    ),
    _ShellDestination(
      label: 'Send',
      icon: Icons.north_east_rounded,
      activeIcon: Icons.north_east_rounded,
    ),
    _ShellDestination(
      label: 'Activity',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    _ShellDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _destinations.length - 1);
    _fromIndex = _currentIndex;
    _toIndex = _currentIndex;
    _startFractionalCenter = _currentIndex + 0.5;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _currentIndex) {
      _onTap(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _computeCurrentFractionalCenter() {
    if (!_controller.isAnimating) {
      return _toIndex + 0.5;
    }
    final t = _controller.value;
    final tCenter = Curves.easeInOutCubic.transform(t);
    final targetCenter = _toIndex + 0.5;
    return lerpDouble(_startFractionalCenter, targetCenter, tCenter) ??
        targetCenter;
  }

  void _onTap(int index) {
    if (index == _currentIndex && !_controller.isAnimating) {
      return;
    }

    HapticFeedback.selectionClick();

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      setState(() {
        _currentIndex = index;
        _fromIndex = index;
        _toIndex = index;
        _startFractionalCenter = index + 0.5;
      });
      _controller.value = 1.0;
      return;
    }

    setState(() {
      _startFractionalCenter = _computeCurrentFractionalCenter();
      _fromIndex = _currentIndex;
      _toIndex = index;
      _currentIndex = index;
    });

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final navBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final navBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final activeIconColor = RootBrandColors.pineGreen;
    final activeLabelColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final inactiveColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final selectedSurface = isDark
        ? RootBrandColors.slatePine
        : const Color(0xFFE8F6F1);
    final selectedBorder = isDark
        ? RootBrandColors.borderPine
        : RootBrandColors.pineGreen.withValues(alpha: 0.25);
    final shadowColor = isDark
        ? const Color(0x33000000)
        : const Color(0x140E1B18);

    final horizontalPadding = context.isCompactWidth
        ? RootSpacing.xs + 4.0
        : RootSpacing.md;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _currentIndex == 0) {
          return;
        }
        _onTap(0);
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  WalletHomePage(
                    onReceiveRequested: () => _onTap(1),
                    onSendRequested: () => _onTap(2),
                    onActivityRequested: () => _onTap(3),
                    onSettingsRequested: () => _onTap(4),
                  ),
                  const ReceivePage(),
                  const SendPage(),
                  const TransactionsPage(),
                  const SettingsPage(),
                ],
              ),
            ),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: (context.viewPadding.bottom > 0 ? 16.0 : 12.0),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: navBg,
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(color: navBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final slotWidth = totalWidth / _destinations.length;
                      const indicatorHMargin = 4.0;
                      const indicatorVMargin = 5.0;
                      const indicatorRadius = 27.0;

                      return Stack(
                        children: [
                          // Liquid Selection Indicator
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final t = _controller.value;
                              final targetCenter = _toIndex + 0.5;
                              final distance =
                                  (_toIndex + 0.5 - _startFractionalCenter)
                                      .abs();
                              final direction =
                                  (_toIndex + 0.5 >= _startFractionalCenter)
                                  ? 1.0
                                  : -1.0;

                              // 1. Center travel with smooth easeInOutCubic
                              final tCenter = Curves.easeInOutCubic.transform(
                                t,
                              );
                              final currentCenter =
                                  lerpDouble(
                                    _startFractionalCenter,
                                    targetCenter,
                                    tCenter,
                                  ) ??
                                  targetCenter;

                              // 2. Liquid horizontal stretch scaled by travel distance (1.15x - 1.35x)
                              final maxStretchFraction =
                                  0.16 + 0.04 * distance.clamp(1.0, 4.0);
                              final stretch = maxStretchFraction * sin(t * pi);

                              // 3. Staggered leading/trailing edge bias
                              // In first half, leading edge shoots forward; in second half, trailing edge catches up
                              final leadBias = cos(t * pi);
                              final leadShare =
                                  0.5 + 0.35 * leadBias * direction;
                              final trailShare = 1.0 - leadShare;

                              final rightOffset =
                                  0.5 +
                                  stretch *
                                      (direction > 0 ? leadShare : trailShare);
                              final leftOffset =
                                  -0.5 -
                                  stretch *
                                      (direction > 0 ? trailShare : leadShare);

                              final fractionalLeft = currentCenter + leftOffset;
                              final fractionalRight =
                                  currentCenter + rightOffset;

                              final pillLeft =
                                  (fractionalLeft * slotWidth +
                                          indicatorHMargin)
                                      .clamp(
                                        indicatorHMargin,
                                        totalWidth - indicatorHMargin - 30.0,
                                      );
                              final pillRight =
                                  (fractionalRight * slotWidth -
                                          indicatorHMargin)
                                      .clamp(
                                        indicatorHMargin + 30.0,
                                        totalWidth - indicatorHMargin,
                                      );
                              final pillWidth = (pillRight - pillLeft).clamp(
                                30.0,
                                totalWidth,
                              );

                              return Positioned(
                                left: pillLeft,
                                top: indicatorVMargin,
                                width: pillWidth,
                                bottom: indicatorVMargin,
                                child: RepaintBoundary(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: selectedSurface,
                                      borderRadius: BorderRadius.circular(
                                        indicatorRadius,
                                      ),
                                      border: Border.all(
                                        color: selectedBorder,
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Synchronized Nav Items
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final t = _controller.value;
                              final isAnimating = _controller.isAnimating;

                              return Row(
                                children: [
                                  for (
                                    var index = 0;
                                    index < _destinations.length;
                                    index++
                                  ) ...[
                                    Expanded(
                                      child: _buildNavItem(
                                        index: index,
                                        t: t,
                                        isAnimating: isAnimating,
                                        activeIconColor: activeIconColor,
                                        activeLabelColor: activeLabelColor,
                                        inactiveColor: inactiveColor,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required double t,
    required bool isAnimating,
    required Color activeIconColor,
    required Color activeLabelColor,
    required Color inactiveColor,
  }) {
    final destination = _destinations[index];
    double activeProgress;

    if (!isAnimating) {
      activeProgress = (index == _currentIndex) ? 1.0 : 0.0;
    } else {
      if (index == _toIndex) {
        // Target destination: color & label smoothly fade in after leading edge
        activeProgress = const Interval(
          0.40,
          1.0,
          curve: Curves.easeOut,
        ).transform(t);
      } else if (index == _fromIndex) {
        // Origin destination: smoothly fades out
        activeProgress =
            1.0 - const Interval(0.0, 0.45, curve: Curves.easeIn).transform(t);
      } else {
        activeProgress = 0.0;
      }
    }

    return _ShellNavItem(
      destination: destination,
      activeProgress: activeProgress,
      onTap: () => _onTap(index),
      activeIconColor: activeIconColor,
      activeLabelColor: activeLabelColor,
      inactiveColor: inactiveColor,
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.destination,
    required this.activeProgress,
    required this.onTap,
    required this.activeIconColor,
    required this.activeLabelColor,
    required this.inactiveColor,
  });

  final _ShellDestination destination;
  final double activeProgress;
  final VoidCallback onTap;
  final Color activeIconColor;
  final Color activeLabelColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = Color.lerp(
      inactiveColor,
      activeIconColor,
      activeProgress,
    )!;
    final labelColor = Color.lerp(
      inactiveColor,
      activeLabelColor,
      activeProgress,
    )!;
    final isSelected = activeProgress > 0.5;

    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? destination.activeIcon : destination.icon,
                size: 22,
                color: iconColor,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
