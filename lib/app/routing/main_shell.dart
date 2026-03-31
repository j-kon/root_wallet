import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
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
    final surface = Theme.of(context).colorScheme.surface;
    final border = AppColors.borderOf(context);
    final shadow = AppColors.shadowOf(context);
    final inactiveColor = AppColors.textSecondaryOf(
      context,
    ).withValues(alpha: 0.76);
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
          top: true,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              0,
              //bottomSpacing,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(AppRadius.lg + 4),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg + 4),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onTap,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Theme.of(context).colorScheme.primary,
                  unselectedItemColor: inactiveColor,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  iconSize: 24,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Wallet',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.qr_code_2_outlined),
                      activeIcon: Icon(Icons.qr_code_2),
                      label: 'Receive',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.north_east),
                      activeIcon: Icon(Icons.north_east_rounded),
                      label: 'Send',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings_outlined),
                      activeIcon: Icon(Icons.settings),
                      label: 'Settings',
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
