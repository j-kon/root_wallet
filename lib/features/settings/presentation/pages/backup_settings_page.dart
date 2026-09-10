import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/settings/presentation/providers/backup_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _ImportBackupDialog(),
    );

    if (result != null && result.trim().isNotEmpty) {
      await ref
          .read(backupControllerProvider.notifier)
          .importFromBase64(result);
    }
  }

  Future<void> _exportToClipboard(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final base64 = await ref
        .read(backupControllerProvider.notifier)
        .exportToBase64();
    if (base64 != null) {
      await Clipboard.setData(ClipboardData(text: base64));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted backup copied to clipboard.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupControllerProvider);
    final isDark = AppColors.isDark(context);

    ref.listen(backupControllerProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: RootBrandColors.error,
          ),
        );
        ref.read(backupControllerProvider.notifier).clearMessages();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: RootBrandColors.pineGreen,
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
          RootSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        children: [
          // Header titles
          Text(
            'Keep your labels & notes safe',
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Encrypted Metadata Backup',
            style: TextStyle(
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.1,
              fontSize: context.isCompactWidth ? 24 : 28,
            ),
          ),
          const SizedBox(height: RootSpacing.lg),

          // 1. OS Auto Cloud Sync Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
              borderRadius: BorderRadius.circular(RootRadius.lg),
              border: Border.all(
                color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.all(RootSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: RootBrandColors.pineGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: RootBrandColors.pineGreen.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.cloud_queue_rounded,
                        color: RootBrandColors.pineGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: RootSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OS Auto Cloud Sync',
                            style: TextStyle(
                              color: isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lastBackupText,
                            style: TextStyle(
                              color: isDark
                                  ? RootBrandColors.mutedSage
                                  : const Color(0xFF5E6F68),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RootSpacing.md),
                Text(
                  'Your backup is fully encrypted on-device using a 256-bit AES key derived from your recovery mnemonic. The backup file resides in the app sandbox, enabling automatic, secure operating system sync to your iCloud or Android Cloud Backup.',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: RootSpacing.lg),
                if (state.isProcessing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: MagneticPressable(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(backupControllerProvider.notifier)
                                .restoreFromFile();
                          },
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? RootBrandColors.slatePine
                                  : const Color(0xFFE8EFEA),
                              borderRadius: BorderRadius.circular(RootRadius.md),
                              border: Border.all(
                                color: isDark
                                    ? RootBrandColors.borderPine
                                    : const Color(0xFFD7E3DC),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              'Restore file',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: RootSpacing.sm),
                      Expanded(
                        child: MagneticPressable(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(backupControllerProvider.notifier)
                                .backupToFile();
                          },
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: RootBrandColors.pineGreen,
                              borderRadius: BorderRadius.circular(RootRadius.md),
                              border: Border.all(
                                color: RootBrandColors.pineGreen,
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'Back up file',
                              style: TextStyle(
                                color: RootBrandColors.pureWhite,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: RootSpacing.lg),

          // 2. Manual Export & Import Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
              borderRadius: BorderRadius.circular(RootRadius.lg),
              border: Border.all(
                color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.all(RootSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual Export & Import',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.warmIvory
                        : RootBrandColors.charcoalPine,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Need to move your labels manually? Copy the encrypted Base64 payload to paste it in another installation of Root Wallet.',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: RootSpacing.lg),
                if (!state.isProcessing)
                  Row(
                    children: [
                      Expanded(
                        child: MagneticPressable(
                          onTap: () => _showImportDialog(context, ref),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? RootBrandColors.slatePine
                                  : const Color(0xFFE8EFEA),
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              border: Border.all(
                                color: isDark
                                    ? RootBrandColors.borderPine
                                    : const Color(0xFFD7E3DC),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.paste_rounded,
                                  size: 16,
                                  color: isDark
                                      ? RootBrandColors.warmIvory
                                      : RootBrandColors.charcoalPine,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Paste & Import',
                                  style: TextStyle(
                                    color: isDark
                                        ? RootBrandColors.warmIvory
                                        : RootBrandColors.charcoalPine,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: RootSpacing.sm),
                      Expanded(
                        child: MagneticPressable(
                          onTap: () => _exportToClipboard(context, ref),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: RootBrandColors.pineGreen,
                              borderRadius:
                                  BorderRadius.circular(RootRadius.md),
                              border: Border.all(
                                color: RootBrandColors.pineGreen,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: RootBrandColors.pureWhite,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Copy & Export',
                                  style: TextStyle(
                                    color: RootBrandColors.pureWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _ImportBackupDialog extends StatefulWidget {
  const _ImportBackupDialog();

  @override
  State<_ImportBackupDialog> createState() => _ImportBackupDialogState();
}

class _ImportBackupDialogState extends State<_ImportBackupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AlertDialog(
      backgroundColor: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RootRadius.lg),
        side: BorderSide(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      title: Text(
        'Import Encrypted Backup',
        style: TextStyle(
          color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste your encrypted Base64 backup text below. Importing will overwrite your current address labels and transaction notes.',
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            style: TextStyle(
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? RootBrandColors.slatePine : const Color(0xFFF6F8F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RootRadius.md),
                borderSide: BorderSide(
                  color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RootRadius.md),
                borderSide: BorderSide(
                  color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RootRadius.md),
                borderSide: const BorderSide(
                  color: RootBrandColors.pineGreen,
                  width: 1.5,
                ),
              ),
              hintText: 'Paste backup payload here...',
              hintStyle: TextStyle(
                color: isDark ? RootBrandColors.mutedSage : const Color(0xFF8B9E95),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: RootBrandColors.pineGreen,
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
