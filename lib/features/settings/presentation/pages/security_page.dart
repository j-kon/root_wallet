import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';

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
        error: (_, _) =>
            const Center(child: Text('Unable to load security settings.')),
        data: (lock) {
          final statusLabel = lock.isLockEnabled
              ? 'Protected by app lock'
              : 'App lock is currently disabled';
          final subtitle = lock.isLockEnabled
              ? 'Review biometrics, auto-lock timing, and PIN posture.'
              : 'Enable lock protection to reduce exposure when the app is reopened.';

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: lock.isLockEnabled
                        ? [AppColors.secondary, AppColors.primary]
                        : [Colors.brown.shade700, AppColors.warning],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable app lock'),
                      subtitle: const Text(
                        'Require unlock on app open or resume.',
                      ),
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable biometrics'),
                      subtitle: Text(
                        lock.isBiometricAvailable
                            ? 'Use Face ID or Touch ID before PIN.'
                            : 'Biometric authentication is not available on this device.',
                      ),
                      value: lock.isBiometricsEnabled,
                      onChanged: lock.isLockEnabled && lock.isBiometricAvailable
                          ? (value) => controller.setBiometricsEnabled(value)
                          : null,
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.password_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(lock.hasPin ? 'Change PIN' : 'Set PIN'),
                      subtitle: const Text('PIN length: 6 digits'),
                      trailing: const Icon(Icons.chevron_right_rounded),
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
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (pin.length != 6) {
                  return;
                }
                Navigator.of(context).pop(pin);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
