import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/features/receive/presentation/pages/receive_page.dart';
import 'package:root_wallet/features/send/presentation/pages/send_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/settings_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/wallet_home_page.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  static const _destinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    _ShellDestination(
      label: 'Receive',
      icon: Icons.qr_code_2_outlined,
      activeIcon: Icons.qr_code_2_rounded,
    ),
    _ShellDestination(
      label: 'Send',
      icon: Icons.north_east_rounded,
      activeIcon: Icons.north_east_rounded,
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
    _currentIndex = widget.initialIndex;
  }

  void _onTap(int index) {
    if (index == _currentIndex) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final navRadius = BorderRadius.circular(RootRadius.lg + 8);
    final isDark = AppColors.isDark(context);

    final navBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final navBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final activeColor = RootBrandColors.pineGreen;
    final inactiveColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final selectedSurface = isDark
        ? RootBrandColors.deepForest
        : const Color(0xFFE8F6F1);
    final selectedBorder = isDark
        ? RootBrandColors.borderPine
        : RootBrandColors.pineGreen.withValues(alpha: 0.25);
    final shadowColor = isDark
        ? const Color(0x33000000)
        : const Color(0x140E1B18);

    final horizontalPadding = context.isCompactWidth
        ? RootSpacing.sm
        : RootSpacing.md;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _currentIndex == 0) {
          return;
        }
        setState(() {
          _currentIndex = 0;
        });
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(child: _buildCurrentTab()),
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: (context.viewPadding.bottom > 0 ? 20.0 : 16.0),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: navBg,
                    borderRadius: navRadius,
                    border: Border.all(color: navBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: RootSpacing.xs,
                    vertical: RootSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      for (var index = 0; index < _destinations.length; index++)
                        Expanded(
                          child: _ShellNavItem(
                            destination: _destinations[index],
                            selected: index == _currentIndex,
                            onTap: () => _onTap(index),
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            selectedSurface: selectedSurface,
                            selectedBorder: selectedBorder,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    return switch (_currentIndex) {
      0 => WalletHomePage(
        onReceiveRequested: () => _onTap(1),
        onSendRequested: () => _onTap(2),
        onSettingsRequested: () => _onTap(3),
      ),
      1 => const ReceivePage(),
      2 => const SendPage(),
      _ => const SettingsPage(),
    };
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
    required this.activeColor,
    required this.inactiveColor,
    required this.selectedSurface,
    required this.selectedBorder,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final Color selectedSurface;
  final Color selectedBorder;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? activeColor : inactiveColor;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(RootRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: RootSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: RootSpacing.md,
                  vertical: RootSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected ? selectedSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(RootRadius.pill),
                  border: Border.all(
                    color: selected ? selectedBorder : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? activeColor : inactiveColor,
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
