import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/shared/widgets/copy_row.dart';

class BackupSeedPage extends ConsumerStatefulWidget {
  const BackupSeedPage({super.key});

  @override
  ConsumerState<BackupSeedPage> createState() => _BackupSeedPageState();
}

class _BackupSeedPageState extends ConsumerState<BackupSeedPage> {
  static const _seed =
      'abandon amount liar amount expire adjust cage candy arch gather drum buyer';

  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backup Seed',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store this recovery phrase offline. Never share it online.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_revealed)
              const CopyRow(value: _seed, label: 'Recovery phrase')
            else
              const InfoBanner(
                type: InfoBannerType.warning,
                message:
                    'For security, re-authenticate before revealing your recovery phrase.',
              ),
            const SizedBox(height: AppSpacing.md),
            if (!_revealed)
              PrimaryButton(
                label: 'Reveal recovery phrase',
                onPressed: _handleReveal,
              ),
            const Spacer(),
            PrimaryButton(
              label: 'I\'ve backed this up',
              onPressed: !_revealed ? null : _markBackupComplete,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReveal() async {
    final security = ref.read(lockControllerProvider).valueOrNull;
    final controller = ref.read(lockControllerProvider.notifier);

    bool ok = await controller.requireReauth();
    if (!ok && security != null && security.hasPin) {
      if (!mounted) {
        return;
      }
      final pin = await _promptPin(context);
      if (pin != null) {
        ok = await controller.verifyPin(pin);
      }
    }

    if (!ok) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required to reveal seed.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _revealed = true;
    });
  }

  Future<void> _markBackupComplete() async {
    await ref.read(backupReminderProvider.notifier).confirmBackup();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Backup marked as complete.')));
    Navigator.of(context).pop();
  }

  Future<String?> _promptPin(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter PIN'),
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
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value;
  }
}
