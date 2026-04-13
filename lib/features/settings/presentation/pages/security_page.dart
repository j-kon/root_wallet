import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockAsync = ref.watch(lockControllerProvider);
    final controller = ref.read(lockControllerProvider.notifier);

    return AppScaffold(
      title: 'Security',
      body: lockAsync.when(
        loading: () => const Loading(label: 'Loading security settings...'),
        error: (error, stackTrace) =>
            const Center(child: Text('Unable to load security settings.')),
        data: (lock) {
          final statusLabel = lock.isLockEnabled
              ? 'Protected by app lock'
              : 'App lock is currently disabled';
          final subtitle = lock.isLockEnabled
              ? 'Review biometrics, auto-lock timing, and PIN posture.'
              : 'Enable lock protection to reduce exposure when the app is reopened.';

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              AppSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing,
            ),
            children: [
              GlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                tint: AppColors.glassSurfaceStrongOf(
                  context,
                ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.95),
                highlightOpacity: 0.05,
                padding: EdgeInsets.all(
                  context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -34,
                      right: -20,
                      child: _SecurityOrb(
                        size: 140,
                        color:
                            (lock.isLockEnabled
                                    ? AppColors.primary
                                    : AppColors.warning)
                                .withValues(alpha: 0.18),
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      left: -34,
                      child: _SecurityOrb(
                        size: 110,
                        color: AppColors.accent.withValues(alpha: 0.12),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _SecurityBadge(
                              icon: Icons.pin_outlined,
                              label: lock.hasPin ? 'PIN set' : 'PIN not set',
                            ),
                            _SecurityBadge(
                              icon: Icons.fingerprint_rounded,
                              label: lock.isBiometricsEnabled
                                  ? 'Biometrics on'
                                  : 'Biometrics off',
                            ),
                            _SecurityBadge(
                              icon: Icons.timer_outlined,
                              label: lock.autoLockOption.label,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (lock.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBanner(
                  type: lock.isInCooldown
                      ? InfoBannerType.warning
                      : InfoBannerType.info,
                  message: lock.message!,
                  icon: lock.isInCooldown
                      ? Icons.hourglass_bottom_rounded
                      : Icons.info_outline_rounded,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _SecurityPanel(
                title: 'Access controls',
                subtitle:
                    'Configure how the wallet is protected when reopened.',
                child: Column(
                  children: [
                    _SecurityToggleTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Enable app lock',
                      subtitle: 'Require unlock on app open or resume.',
                      value: lock.isLockEnabled,
                      onChanged: (enabled) async {
                        if (enabled && !lock.hasPin) {
                          final pin = await _promptPinSetup(context);
                          if (pin == null) {
                            return;
                          }
                          await controller.setPin(pin);
                        }

                        final ok = await controller.setLockEnabled(enabled);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Set a 6-digit PIN before enabling app lock.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SecurityToggleTile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Enable biometrics',
                      subtitle: lock.isBiometricAvailable
                          ? 'Use Face ID or Touch ID before PIN.'
                          : 'Biometric authentication is not available on this device.',
                      value: lock.isBiometricsEnabled,
                      enabled: lock.isLockEnabled && lock.isBiometricAvailable,
                      onChanged: lock.isLockEnabled && lock.isBiometricAvailable
                          ? (value) => controller.setBiometricsEnabled(value)
                          : (_) {},
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Auto-lock timing',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Choose when the wallet should lock again after leaving the app.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<AutoLockOption>(
                      decoration: const InputDecoration(
                        labelText: 'Auto-lock timing',
                      ),
                      initialValue: lock.autoLockOption,
                      onChanged: lock.isLockEnabled
                          ? (value) {
                              if (value == null) {
                                return;
                              }
                              controller.setAutoLockOption(value);
                            }
                          : null,
                      items: [
                        for (final option in AutoLockOption.values)
                          DropdownMenuItem<AutoLockOption>(
                            value: option,
                            child: Text(option.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SecurityPanel(
                title: 'PIN management',
                subtitle: 'Update the credential used for manual unlock.',
                child: Column(
                  children: [
                    _SecurityActionTile(
                      icon: Icons.password_rounded,
                      title: lock.hasPin ? 'Change PIN' : 'Set PIN',
                      subtitle: 'PIN length: 6 digits',
                      onTap: () async {
                        final pin = await _promptPinSetup(context);
                        if (pin == null) {
                          return;
                        }
                        await controller.setPin(pin);
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN updated.')),
                        );
                      },
                    ),
                    if (lock.isLockEnabled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: controller.lockNow,
                          icon: const Icon(Icons.lock_clock_outlined),
                          label: const Text('Lock now'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _promptPinSetup(BuildContext context) async {
    final first = await _promptPin(context, title: 'Set 6-digit PIN');
    if (first == null) {
      return null;
    }
    if (!context.mounted) {
      return null;
    }

    final second = await _promptPin(context, title: 'Confirm PIN');
    if (second == null) {
      return null;
    }

    if (first != second) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs did not match. Try again.')),
        );
      }
      return null;
    }

    return first;
  }

  Future<String?> _promptPin(
    BuildContext context, {
    required String title,
  }) async {
    return showPinEntryDialog(
      context,
      title: title,
      subtitle: 'Choose a 6-digit PIN that you can remember confidently.',
      confirmLabel: 'Save',
    );
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
      highlightOpacity: 0.05,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 224.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        tint: AppColors.glassSurfaceOf(
          context,
        ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.88),
        borderColor: AppColors.glassBorderOf(context).withValues(alpha: 0.72),
        shadowColor: Colors.transparent,
        highlightOpacity: 0.03,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryOf(context)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                  fontSize: context.isVeryCompactWidth ? 11.5 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityToggleTile extends StatelessWidget {
  const _SecurityToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.md),
        tint: AppColors.glassSurfaceOf(
          context,
        ).withValues(alpha: AppColors.isDark(context) ? 0.48 : 0.92),
        highlightOpacity: 0.04,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityActionTile extends StatelessWidget {
  const _SecurityActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.md),
          tint: AppColors.glassSurfaceOf(
            context,
          ).withValues(alpha: AppColors.isDark(context) ? 0.48 : 0.92),
          highlightOpacity: 0.04,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityOrb extends StatelessWidget {
  const _SecurityOrb({required this.size, required this.color});

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
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
