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

  late final AnimationController _controller;
  late final Animation<double> _animation;

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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

  void _onTap(int index) {
    if (index == _currentIndex && !_controller.isAnimating) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
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
                          // Sliding pill indicator
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, _) {
                              final t = _animation.value;
                              final centerFrom = (_fromIndex + 0.5) * slotWidth;
                              final centerTo = (_toIndex + 0.5) * slotWidth;
                              final currentCenter =
                                  lerpDouble(centerFrom, centerTo, t) ??
                                  centerTo;

                              // Subtle fluid stretch during transition
                              final stretch =
                                  sin(t * pi) *
                                  12.0 *
                                  (_toIndex != _fromIndex ? 1.0 : 0.0);
                              final baseWidth =
                                  slotWidth - (indicatorHMargin * 2);
                              final pillWidth = baseWidth + stretch;
                              final pillLeft = currentCenter - (pillWidth / 2);

                              return Positioned(
                                left: pillLeft,
                                top: indicatorVMargin,
                                width: pillWidth,
                                bottom: indicatorVMargin,
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
                              );
                            },
                          ),

                          // Row of items
                          Row(
                            children: [
                              for (
                                var index = 0;
                                index < _destinations.length;
                                index++
                              )
                                Expanded(
                                  child: _ShellNavItem(
                                    destination: _destinations[index],
                                    selected: index == _currentIndex,
                                    onTap: () => _onTap(index),
                                    activeIconColor: activeIconColor,
                                    activeLabelColor: activeLabelColor,
                                    inactiveColor: inactiveColor,
                                  ),
                                ),
                            ],
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
    required this.selected,
    required this.onTap,
    required this.activeIconColor,
    required this.activeLabelColor,
    required this.inactiveColor,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color activeIconColor;
  final Color activeLabelColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? activeIconColor : inactiveColor;
    final labelColor = selected ? activeLabelColor : inactiveColor;

    return Semantics(
      selected: selected,
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
                selected ? destination.activeIcon : destination.icon,
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
