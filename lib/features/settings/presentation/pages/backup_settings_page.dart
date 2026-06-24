import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/features/settings/presentation/providers/backup_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Encrypted Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your encrypted Base64 backup text below. Importing will overwrite your current address labels and transaction notes.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Paste backup payload here...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.trim().isNotEmpty) {
      await ref.read(backupControllerProvider.notifier).importFromBase64(result);
    }
  }

  Future<void> _exportToClipboard(BuildContext context, WidgetRef ref) async {
    final base64 = await ref.read(backupControllerProvider.notifier).exportToBase64();
    if (base64 != null) {
      await Clipboard.setData(ClipboardData(text: base64));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupControllerProvider);
    final textSecondary = AppColors.textSecondaryOf(context);

    ref.listen(backupControllerProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
          ),
        );
        ref.read(backupControllerProvider.notifier).clearMessages();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(backupControllerProvider.notifier).clearMessages();
      }
    });

    final lastBackupText = state.lastBackupTime != null
        ? 'Last backup: ${state.lastBackupTime!.toLocal().toString().split('.')[0]}'
        : 'Never backed up';

    return AppScaffold(
      title: 'Cloud & Metadata Backup',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        children: [
          Text(
            'Keep your labels & notes safe',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: textSecondary,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Encrypted Metadata Backup',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  height: 1.05,
                  fontSize: context.isCompactWidth ? 26 : 30,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            tint: AppColors.glassSurfaceStrongOf(context).withValues(
              alpha: AppColors.isDark(context) ? 0.62 : 0.95,
            ),
            highlightOpacity: 0.05,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.cloud_queue_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OS Auto Cloud Sync',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lastBackupText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your backup is fully encrypted on-device using a 256-bit AES key derived from your recovery mnemonic. The backup file resides in the app sandbox, enabling automatic, secure operating system sync to your iCloud or Android Cloud Backup.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state.isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(backupControllerProvider.notifier).restoreFromFile(),
                          child: const Text('Restore file'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              ref.read(backupControllerProvider.notifier).backupToFile(),
                          child: const Text('Back up file'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            tint: AppColors.glassSurfaceOf(context).withValues(
              alpha: AppColors.isDark(context) ? 0.58 : 0.95,
            ),
            highlightOpacity: 0.05,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual Export & Import',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Need to move your labels manually? Copy the encrypted Base64 payload to paste it in another installation of Root Wallet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!state.isProcessing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showImportDialog(context, ref),
                          icon: const Icon(Icons.paste_rounded, size: 16),
                          label: const Text('Paste & Import'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _exportToClipboard(context, ref),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy & Export'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
