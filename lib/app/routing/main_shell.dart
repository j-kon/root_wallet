import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
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
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
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
    final isDark = AppColors.isDark(context);
    final primary = AppColors.primaryOf(context);
    final inactiveColor = AppColors.textSecondaryOf(
      context,
    ).withValues(alpha: isDark ? 0.88 : 0.84);
    final horizontalPadding = context.isCompactWidth
        ? AppSpacing.sm
        : AppSpacing.md;
    final tabs = <Widget>[
      WalletHomePage(
        onReceiveRequested: () => _onTap(1),
        onSendRequested: () => _onTap(2),
        onSettingsRequested: () => _onTap(3),
      ),
      const ReceivePage(),
      const SendPage(),
      const SettingsPage(),
    ];

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
        body: IndexedStack(index: _currentIndex, children: tabs),
        bottomNavigationBar: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              AppSpacing.xs,
            ),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(AppRadius.lg + 6),
              blur: 18,
              tint: AppColors.glassSurfaceOf(
                context,
              ).withValues(alpha: isDark ? 0.84 : 0.90),
              borderColor: AppColors.glassBorderOf(
                context,
              ).withValues(alpha: isDark ? 0.44 : 0.78),
              highlightOpacity: isDark ? 0.04 : 0.06,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowOf(
                    context,
                  ).withValues(alpha: isDark ? 0.44 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < _destinations.length; index++)
                      Expanded(
                        child: _ShellNavItem(
                          destination: _destinations[index],
                          selected: index == _currentIndex,
                          onTap: () => _onTap(index),
                          activeColor: primary,
                          inactiveColor: inactiveColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
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
    required this.activeColor,
    required this.inactiveColor,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final pillColor = selected
        ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
        : Colors.transparent;
    final borderColor = selected
        ? activeColor.withValues(alpha: isDark ? 0.34 : 0.18)
        : Colors.transparent;
    final iconColor = selected ? activeColor : inactiveColor;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? activeColor : inactiveColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
