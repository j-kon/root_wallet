import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/app_splash_screen.dart';
import 'package:root_wallet/features/settings/presentation/pages/lock_screen.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';

class AppSecurityGate extends ConsumerStatefulWidget {
  const AppSecurityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppSecurityGate> createState() => _AppSecurityGateState();
}

class _AppSecurityGateState extends ConsumerState<AppSecurityGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(lockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        controller.onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        controller.onAppResumed();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockAsync = ref.watch(lockControllerProvider);
    final isLocked = lockAsync.valueOrNull?.isLocked ?? false;

    return Stack(
      children: [
        widget.child,
        if (lockAsync.isLoading)
          const Positioned.fill(
            child: AppSplashScreen(statusLabel: 'Initializing security...'),
          ),
        if (isLocked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
