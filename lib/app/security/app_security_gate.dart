import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
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
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.backgroundOf(context).withValues(alpha: 0.84),
              child: Center(
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  tint: AppColors.glassSurfaceStrongOf(
                    context,
                  ).withValues(alpha: AppColors.isDark(context) ? 0.68 : 0.96),
                  highlightOpacity: 0.05,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    'Initializing security...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (isLocked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
