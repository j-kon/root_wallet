import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class Bip329LabelsPage extends ConsumerStatefulWidget {
  const Bip329LabelsPage({super.key});

  @override
  ConsumerState<Bip329LabelsPage> createState() => _Bip329LabelsPageState();
}

class _Bip329LabelsPageState extends ConsumerState<Bip329LabelsPage> {
  Future<void> _exportLabels(BuildContext context) async {
    HapticFeedback.lightImpact();
    final snapshotAsync = ref.read(walletLabelsControllerProvider);
    final snapshot = snapshotAsync.valueOrNull;
    if (snapshot == null) return;

    final bip329Service = ref.read(bip329ServiceProvider);
    final jsonl = bip329Service.exportJsonl(snapshot);

    if (jsonl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No labels found to export.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: jsonl));

    // Safe clipboard clearing: clear after 60s only if clipboard still matches exported data
    Timer(const Duration(seconds: 60), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == jsonl) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'BIP-329 labels copied to clipboard (JSONL). '
            'Warning: labels contain personal metadata. Clipboard will auto-clear in 60s.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final isDark = AppColors.isDark(dialogContext);
        return AlertDialog(
          backgroundColor:
              isDark ? RootBrandColors.charcoalPine : RootBrandColors.warmIvory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RootRadius.lg),
          ),
          title: Text(
            'Import BIP-329 Labels',
            style: TextStyle(
              color:
                  isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste BIP-329 formatted JSON Lines (records for tx, addr, or output).',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : RootBrandColors.charcoalPine,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark
                        ? RootBrandColors.warmIvory
                        : RootBrandColors.charcoalPine,
                  ),
                  decoration: InputDecoration(
                    hintText: '{"type":"tx","ref":"...","label":"..."}\n...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? RootBrandColors.borderPine
                          : RootBrandColors.mutedSage,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RootRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: RootBrandColors.pineGreen,
                foregroundColor: RootBrandColors.warmIvory,
              ),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      try {
        final bip329Service = ref.read(bip329ServiceProvider);
        final currentSnapshot =
            ref.read(walletLabelsControllerProvider).valueOrNull;
        final parseResult = bip329Service.parseJsonl(
          result,
          existingSnapshot: currentSnapshot,
        );

        await ref
            .read(walletLabelsControllerProvider.notifier)
            .importSnapshot(parseResult.snapshot);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${parseResult.importedCount} label(s)'
                '${parseResult.skippedCount > 0 ? " (${parseResult.skippedCount} skipped/ignored)" : ""}.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import failed: $e'),
              backgroundColor: RootBrandColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmClearLabels(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = AppColors.isDark(dialogContext);
        return AlertDialog(
          backgroundColor:
              isDark ? RootBrandColors.charcoalPine : RootBrandColors.warmIvory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RootRadius.lg),
          ),
          title: Text(
            'Clear All Labels?',
            style: TextStyle(
              color:
                  isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will delete all locally stored transaction, address, and UTXO labels. This action cannot be undone.',
            style: TextStyle(
              color:
                  isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: RootBrandColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(walletLabelsControllerProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local labels have been deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final labelsAsync = ref.watch(walletLabelsControllerProvider);
    final snapshot = labelsAsync.valueOrNull;

    final addrCount = snapshot?.addressLabels.length ?? 0;
    final txCount = snapshot?.transactionMetadata.length ?? 0;
    final utxoCount = snapshot?.outputLabels.length ?? 0;

    return AppScaffold(
      title: 'Wallet Labels (BIP-329)',
      body: ListView(
        padding: const EdgeInsets.all(RootSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(RootSpacing.lg),
            decoration: BoxDecoration(
              color: isDark
                  ? RootBrandColors.nightPine
                  : RootBrandColors.pureWhite,
              borderRadius: BorderRadius.circular(RootRadius.lg),
              border: Border.all(
                color: isDark
                    ? RootBrandColors.borderPine
                    : const Color(0xFFD7E3DC),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.label_outline,
                      color: RootBrandColors.pineGreen,
                      size: 24,
                    ),
                    const SizedBox(width: RootSpacing.sm),
                    Text(
                      'Label Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RootSpacing.md),
                _buildStatRow(
                  label: 'Labeled Transactions',
                  count: txCount,
                  isDark: isDark,
                ),
                const Divider(),
                _buildStatRow(
                  label: 'Labeled Addresses',
                  count: addrCount,
                  isDark: isDark,
                ),
                const Divider(),
                _buildStatRow(
                  label: 'Labeled UTXOs (Outputs)',
                  count: utxoCount,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: RootSpacing.lg),
          MagneticPressable(
            onTap: () => _exportLabels(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: RootSpacing.md,
                horizontal: RootSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: RootBrandColors.pineGreen,
                borderRadius: BorderRadius.circular(RootRadius.md),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy, color: RootBrandColors.warmIvory, size: 20),
                  SizedBox(width: RootSpacing.sm),
                  Text(
                    'Export Labels (BIP-329 JSONL)',
                    style: TextStyle(
                      color: RootBrandColors.warmIvory,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          MagneticPressable(
            onTap: () => _showImportDialog(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: RootSpacing.md,
                horizontal: RootSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? RootBrandColors.nightPine
                    : RootBrandColors.pureWhite,
                borderRadius: BorderRadius.circular(RootRadius.md),
                border: Border.all(
                  color: RootBrandColors.pineGreen,
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    color: RootBrandColors.pineGreen,
                    size: 20,
                  ),
                  SizedBox(width: RootSpacing.sm),
                  Text(
                    'Import Labels (BIP-329)',
                    style: TextStyle(
                      color: RootBrandColors.pineGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (txCount > 0 || addrCount > 0 || utxoCount > 0) ...[
            const SizedBox(height: RootSpacing.md),
            MagneticPressable(
              onTap: () => _confirmClearLabels(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: RootSpacing.md,
                  horizontal: RootSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(RootRadius.md),
                  border: Border.all(color: RootBrandColors.error),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: RootBrandColors.error,
                      size: 20,
                    ),
                    SizedBox(width: RootSpacing.sm),
                    Text(
                      'Clear All Labels',
                      style: TextStyle(
                        color: RootBrandColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: RootSpacing.xl),
          Container(
            padding: const EdgeInsets.all(RootSpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? RootBrandColors.slatePine
                  : const Color(0xFFE8EFEA),
              borderRadius: BorderRadius.circular(RootRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: RootBrandColors.pineGreen,
                  size: 20,
                ),
                const SizedBox(width: RootSpacing.sm),
                Expanded(
                  child: Text(
                    'Wallet labels are stored locally and are not sent to configured Esplora or Electrum backends. Copying or exporting labels places that data outside Root Wallet\'s local label store, for example on the system clipboard.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : RootBrandColors.charcoalPine,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required String label,
    required int count,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RootSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? RootBrandColors.mutedSage
                  : RootBrandColors.charcoalPine,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
            ),
          ),
        ],
      ),
    );
  }
}
