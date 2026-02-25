import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/shared/widgets/copy_row.dart';

class BackupSeedPage extends ConsumerWidget {
  const BackupSeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const seed =
        'abandon amount liar amount expire adjust cage candy arch gather drum buyer';

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
            const CopyRow(value: seed, label: 'Recovery phrase'),
            const Spacer(),
            PrimaryButton(
              label: 'I\'ve backed this up',
              onPressed: () async {
                await ref.read(backupReminderProvider.notifier).confirmBackup();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup marked as complete.')),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
