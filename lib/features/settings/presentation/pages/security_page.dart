import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load security settings.')),
        data: (lock) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SwitchListTile.adaptive(
                title: const Text('Enable app lock'),
                subtitle: const Text('Require unlock on app open/resume.'),
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
              if (lock.isBiometricAvailable)
                SwitchListTile.adaptive(
                  title: const Text('Enable biometrics'),
                  subtitle: const Text('Use Face ID / Touch ID before PIN.'),
                  value: lock.isBiometricsEnabled,
                  onChanged: lock.isLockEnabled
                      ? (value) => controller.setBiometricsEnabled(value)
                      : null,
                ),
              ListTile(
                title: const Text('Auto-lock timing'),
                subtitle: const Text('When app comes back from background.'),
                trailing: DropdownButton<AutoLockOption>(
                  value: lock.autoLockOption,
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
              ),
              ListTile(
                title: Text(lock.hasPin ? 'Change PIN' : 'Set PIN'),
                subtitle: const Text('PIN length: 6 digits'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final pin = await _promptPinSetup(context);
                  if (pin == null) {
                    return;
                  }
                  await controller.setPin(pin);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('PIN updated.')));
                },
              ),
              if (lock.message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                InfoBanner(
                  type: InfoBannerType.warning,
                  message: lock.message!,
                ),
              ],
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
