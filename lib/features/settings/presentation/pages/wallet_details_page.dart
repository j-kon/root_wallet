import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

class WalletDetailsArgs {
  const WalletDetailsArgs({required this.wallet});
  final WalletRecord wallet;
}

class WalletDetailsPage extends ConsumerStatefulWidget {
  const WalletDetailsPage({
    super.key,
    required this.walletId,
  });

  final String walletId;

  @override
  ConsumerState<WalletDetailsPage> createState() => _WalletDetailsPageState();
}

class _WalletDetailsPageState extends ConsumerState<WalletDetailsPage> {
  bool _isDeleting = false;

  Future<void> _showRenameDialog(BuildContext context, WalletRecord wallet) async {
    final controller = TextEditingController(text: wallet.name);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Rename Wallet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('rename_wallet_input'),
                    controller: controller,
                    autofocus: true,
                    maxLength: 32,
                    decoration: InputDecoration(
                      labelText: 'Wallet Name',
                      errorText: errorText,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        if (val.trim().isEmpty) {
                          errorText = 'Name cannot be empty';
                        } else if (val.trim().length > 32) {
                          errorText = 'Name too long (max 32 characters)';
                        } else {
                          errorText = null;
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const ValueKey('rename_wallet_save_btn'),
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (!WalletRecord.isValidName(newName)) {
                      setDialogState(() {
                        errorText = 'Invalid name';
                      });
                      return;
                    }
                    try {
                      await ref
                          .read(walletsListProvider.notifier)
                          .renameWallet(wallet.id, newName);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorText = e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDelete(BuildContext context, WalletRecord wallet, int totalWallets) async {
    if (totalWallets <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the only wallet. Root Wallet requires at least one wallet.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${wallet.name}"?'),
        content: const Text(
          'This will permanently delete this wallet, its local keys, database, BIP-329 labels, '
          'and settings from this device.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const ValueKey('confirm_delete_wallet_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // If signing wallet, require authentication
    if (!wallet.isWatchOnly) {
      final lockController = ref.read(lockControllerProvider.notifier);
      final authOk = await lockController.requireSensitiveActionAuthentication(
        biometricReason: 'Authorize wallet deletion',
        onNoPinConfigured: () {},
        promptPin: () => showPinEntryDialog(
          context,
          title: 'Authorize Deletion',
          subtitle: 'Enter your PIN to confirm deleting this wallet.',
          confirmLabel: 'Delete',
        ),
      );

      if (!authOk) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication required to delete wallet.')),
          );
        }
        return;
      }
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref.read(walletsListProvider.notifier).deleteWallet(wallet.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wallet "${wallet.name}" deleted.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting wallet: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textPrimary = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final textSecondary = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);
    final cardBg = isDark ? RootBrandColors.slatePine : Colors.white;
    final borderColor = isDark
        ? RootBrandColors.borderPine
        : RootBrandColors.charcoalPine.withValues(alpha: 0.12);

    final walletsAsync = ref.watch(walletsListProvider);

    return walletsAsync.when(
      loading: () => const AppScaffold(
        title: 'Wallet Details',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Wallet Details',
        body: Center(child: Text('Error: $e')),
      ),
      data: (wallets) {
        final wallet = wallets.cast<WalletRecord?>().firstWhere(
              (w) => w?.id == widget.walletId,
              orElse: () => null,
            );

        if (wallet == null) {
          return AppScaffold(
            title: 'Wallet Details',
            body: Center(
              child: Text(
                'Wallet not found.',
                style: TextStyle(color: textSecondary),
              ),
            ),
          );
        }

        final isSelected = wallet.isActive;
        final totalWallets = wallets.length;

        return AppScaffold(
          title: wallet.name,
          actions: [
            IconButton(
              key: const ValueKey('wallet_details_rename_btn'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Rename',
              onPressed: () => _showRenameDialog(context, wallet),
            ),
          ],
          body: _isDeleting
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(RootSpacing.lg),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(RootSpacing.lg),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(RootRadius.lg),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? RootBrandColors.pineGreen
                                  : (isDark
                                      ? RootBrandColors.borderPine
                                      : RootBrandColors.charcoalPine.withValues(alpha: 0.06)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              wallet.isWatchOnly
                                  ? Icons.visibility_outlined
                                  : Icons.account_balance_wallet_outlined,
                              color: isSelected ? Colors.white : textSecondary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: RootSpacing.md),
                          Text(
                            wallet.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: RootSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RootBrandColors.pineGreen
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      RootRadius.xs,
                                    ),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: RootBrandColors.pineGreen,
                                    ),
                                  ),
                                ),
                              if (wallet.isWatchOnly) ...[
                                if (isSelected) const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RootBrandColors.amberAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      RootRadius.xs,
                                    ),
                                  ),
                                  child: const Text(
                                    'WATCH ONLY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: RootBrandColors.amberAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RootSpacing.lg),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(RootRadius.lg),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            context: context,
                            label: 'Type',
                            value: wallet.isWatchOnly ? 'Watch-Only' : 'Signing Wallet',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                          _buildDetailRow(
                            context: context,
                            label: 'Script Type',
                            value: wallet.scriptType.displayName,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                          _buildDetailRow(
                            context: context,
                            label: 'Fingerprint',
                            value: wallet.fingerprint,
                            isMonospace: true,
                            canCopy: true,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                          _buildDetailRow(
                            context: context,
                            label: 'Network',
                            value: wallet.network.toUpperCase(),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                          _buildDetailRow(
                            context: context,
                            label: 'Created',
                            value: AppDateTime.ymdHm(wallet.createdAt),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                          _buildDetailRow(
                            context: context,
                            label: 'ID',
                            value: wallet.id,
                            isMonospace: true,
                            canCopy: true,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RootSpacing.xl),
                    if (!isSelected) ...[
                      ElevatedButton.icon(
                        key: const ValueKey('wallet_details_set_active_btn'),
                        onPressed: () async {
                          await ref
                              .read(activeWalletIdProvider.notifier)
                              .setActiveWallet(wallet.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched to "${wallet.name}".'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Set as Active Wallet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RootBrandColors.pineGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RootRadius.lg),
                          ),
                        ),
                      ),
                      const SizedBox(height: RootSpacing.md),
                    ],
                    OutlinedButton.icon(
                      key: const ValueKey('wallet_details_delete_btn'),
                      onPressed: () => _handleDelete(context, wallet, totalWallets),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      label: const Text(
                        'Delete Wallet',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RootRadius.lg),
                        ),
                      ),
                    ),
                    if (totalWallets <= 1) ...[
                      const SizedBox(height: RootSpacing.sm),
                      Center(
                        child: Text(
                          'Root Wallet requires at least one wallet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required String label,
    required String value,
    bool isMonospace = false,
    bool canCopy = false,
    required Color textPrimary,
    required Color textSecondary,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RootSpacing.md,
        vertical: RootSpacing.sm + 4,
      ),
      decoration: borderColor != null
          ? BoxDecoration(border: Border(bottom: BorderSide(color: borderColor)))
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(width: RootSpacing.md),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: isMonospace ? 'monospace' : null,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied $label to clipboard.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
