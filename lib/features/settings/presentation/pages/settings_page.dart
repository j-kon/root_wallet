import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/theme_mode_provider.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Settings Page adhering strictly to Root Wallet Brand Guidelines.
/// Features a solid-surface Security & Health Card, grouped settings sections,
/// clean segmented appearance control, and polished typography.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = Theme.of(context).platform;
    final useCupertino = platform == TargetPlatform.iOS;
    final isDark = AppColors.isDark(context);

    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    final walletState = ref.watch(walletControllerProvider).valueOrNull;
    final lockState = ref.watch(lockControllerProvider).valueOrNull;
    final backupConfirmed =
        ref.watch(backupReminderProvider).valueOrNull ?? false;
    final hideBalances = ref.watch(balancePrivacyProvider).valueOrNull ?? false;
    final env = ref.watch(appEnvProvider);
    final now = ref.watch(dateTimeNowProvider)();
    final updatedAgo = walletState?.lastSyncedAt == null
        ? null
        : AppDateTime.updatedAgo(
            walletState!.lastSyncedAt,
            now: now,
          ).replaceFirst('Updated ', '');

    final isLockActive =
        (lockState?.isLockEnabled ?? false) && (lockState?.hasPin ?? false);
    final healthReady = backupConfirmed && isLockActive;

    final customNode = ref.watch(customNodeProvider).valueOrNull;
    final wallets = ref.watch(walletsListProvider).valueOrNull ?? const [];
    final activeWallet = ref.watch(activeWalletRecordProvider);

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          RootSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        children: [
          // 1. Security & Wallet Health Overview Card
          _HealthOverviewCard(
            healthReady: healthReady,
            backupConfirmed: backupConfirmed,
            isLockActive: isLockActive,
            hideBalances: hideBalances,
            flavor: env.flavor,
            isSyncing: walletState?.isSyncing ?? false,
            isOffline: walletState?.isOffline ?? false,
            updatedAgo: updatedAgo,
            onRefreshSync: () async {
              HapticFeedback.selectionClick();
              await ref.read(walletHomeControllerProvider.notifier).sync();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet sync requested.')),
              );
            },
          ),
          const SizedBox(height: RootSpacing.lg),

          // 2. Wallets Section
          const _SectionHeader(title: 'Wallets'),
          const SizedBox(height: RootSpacing.xs),
          _SettingsSectionCard(
            children: [
              _SettingsRow(
                key: const ValueKey('settings_wallets_row'),
                icon: useCupertino
                    ? CupertinoIcons.rectangle_stack_fill
                    : Icons.account_balance_wallet_outlined,
                title: 'Manage Wallets',
                subtitle: activeWallet != null
                    ? '${activeWallet.name} (${activeWallet.isWatchOnly ? 'Watch-Only' : 'Signing'})'
                    : 'Switch, add or remove wallets',
                badgeText:
                    '${wallets.length} ${wallets.length == 1 ? 'Wallet' : 'Wallets'}',
                badgeTone: RootBrandColors.pineGreen,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.wallets);
                },
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.lg),

          // 3. Appearance Section
          const _SectionHeader(title: 'Appearance'),
          const SizedBox(height: RootSpacing.xs),
          _SettingsSectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(RootSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interface Theme',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how the wallet appears on this device.',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: RootSpacing.md),
                    _AppearanceSegmentedControl(
                      currentMode: themeMode,
                      onChanged: (mode) {
                        HapticFeedback.selectionClick();
                        ref.read(themeModeProvider.notifier).setThemeMode(mode);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.lg),

          // 3. Security & Privacy Section
          const _SectionHeader(title: 'Security & Privacy'),
          const SizedBox(height: RootSpacing.xs),
          _SettingsSectionCard(
            children: [
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.lock_shield_fill
                    : Icons.security_rounded,
                title: 'Security & App Lock',
                subtitle: isLockActive
                    ? 'PIN & biometric authentication active'
                    : 'Set up PIN, biometrics & auto-lock',
                badgeText: isLockActive ? 'Active' : 'Setup needed',
                badgeTone: isLockActive
                    ? RootBrandColors.pineGreen
                    : RootBrandColors.amberAccent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.security);
                },
              ),
              _SettingsRow(
                icon: Icons.vpn_key_rounded,
                title: 'Recovery Phrase',
                subtitle: backupConfirmed
                    ? '12-word seed backup verified'
                    : 'Back up your seed to avoid loss of funds',
                badgeText: backupConfirmed ? 'Verified' : 'Action needed',
                badgeTone: backupConfirmed
                    ? RootBrandColors.pineGreen
                    : RootBrandColors.amberAccent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(
                    AppRoutes.backupSeed,
                    arguments: const BackupSeedPageArgs(
                      requireReauth: true,
                      isOnboardingFlow: false,
                    ),
                  );
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.cloud_upload_fill
                    : Icons.cloud_upload_rounded,
                title: 'Backup & Restore Metadata',
                subtitle: 'Encrypted labels, notes and configurations',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.backupMetadata);
                },
              ),
              _SettingsToggleRow(
                icon: useCupertino
                    ? CupertinoIcons.eye_slash_fill
                    : Icons.visibility_off_rounded,
                title: 'Hide Balances',
                subtitle: 'Mask amounts on overview and activity screens',
                value: hideBalances,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  ref.read(balancePrivacyProvider.notifier).setHidden(value);
                },
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.lg),

          // 4. Network & Advanced Section
          const _SectionHeader(title: 'Network & Advanced'),
          const SizedBox(height: RootSpacing.xs),
          _SettingsSectionCard(
            children: [
              _SettingsRow(
                icon: useCupertino ? CupertinoIcons.link : Icons.lan_outlined,
                title: 'Electrum Node Connection',
                subtitle: customNode != null
                    ? 'Custom: $customNode'
                    : 'Default public testnet node',
                badgeText: customNode != null ? 'Custom' : 'Default',
                badgeTone: customNode != null
                    ? RootBrandColors.amberAccent
                    : RootBrandColors.pineGreen,
                onTap: () => _editCustomElectrumNode(context, ref),
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.slider_horizontal_3
                    : Icons.toll_rounded,
                title: 'Coin Control (UTXO)',
                subtitle: 'Manage, inspect and freeze specific unspent outputs',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.coinControl);
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.doc_text_search
                    : Icons.description_outlined,
                title: 'PSBT Operations',
                subtitle:
                    'Import, inspect, sign, or broadcast partially signed transactions',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.psbtImport);
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.tag
                    : Icons.label_outline_rounded,
                title: 'Wallet Labels (BIP-329)',
                subtitle:
                    'Import or export local labels for addresses, txs, and coins',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.bip329Labels);
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.waveform_path_ecg
                    : Icons.health_and_safety_outlined,
                title: 'Wallet Diagnostics',
                subtitle: 'Inspect backend node, cache and internal latency',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.diagnostics);
                },
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.lg),

          // 5. Wallet Management Section
          const _SectionHeader(title: 'Wallet Operations'),
          const SizedBox(height: RootSpacing.xs),
          _SettingsSectionCard(
            children: [
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.arrow_clockwise_circle_fill
                    : Icons.sync_rounded,
                title: 'Force Blockchain Sync',
                subtitle: 'Rescan mempool and blocks for fresh activity',
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await ref.read(walletHomeControllerProvider.notifier).sync();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wallet sync requested.')),
                  );
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.plus_circle_fill
                    : Icons.add_circle_outline_rounded,
                title: 'Create New Wallet',
                subtitle: 'Set up an additional testnet wallet',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.createWallet);
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.arrow_2_circlepath_circle_fill
                    : Icons.restore_rounded,
                title: 'Restore Wallet',
                subtitle: 'Import existing wallet from 12-word seed phrase',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.restoreWallet);
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.eye_fill
                    : Icons.visibility_outlined,
                title: 'Import Watch-Only Wallet',
                subtitle: 'Monitor addresses and construct unsigned transactions',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.importWatchOnly);
                },
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.trash_fill
                    : Icons.delete_outline_rounded,
                title: 'Delete Local Wallet',
                subtitle: 'Erase wallet data. Seed phrase required to recover.',
                iconTone: RootBrandColors.error,
                titleColor: RootBrandColors.error,
                onTap: () => _deleteLocalWallet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.lg),

          // 6. Help & Info Section (Keep string 'Help and app info' for test compatibility)
          const _SectionHeader(title: 'Help and app info'),
          const SizedBox(height: RootSpacing.xs),
          _SettingsSectionCard(
            children: [
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.question_circle_fill
                    : Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Read documentation or copy the support link',
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () => _openSupport(context, ref),
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.compass_fill
                    : Icons.explore_outlined,
                title: 'Public Testnet Explorer',
                subtitle: 'Inspect live mempool and blocks on mempool.space',
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () => _openExternalLink(
                  context,
                  ref,
                  AppConstants.testnetExplorerBaseUrl,
                  copiedMessage: 'Explorer URL copied.',
                ),
              ),
              _SettingsRow(
                icon: useCupertino
                    ? CupertinoIcons.info_circle_fill
                    : Icons.info_outline_rounded,
                title: 'About Root Wallet',
                subtitle: 'Architecture, self-custody principles and version',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(AppRoutes.about);
                },
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.xl),

          // 7. Brand Footer
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: RootBrandColors.pineGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: RootSpacing.xs),
                    Text(
                      'Root Wallet',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Own Bitcoin from the root.',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: RootSpacing.xs),
                Text(
                  'v1.0.0 (${env.flavor.toUpperCase()}) • Testnet',
                  style: TextStyle(
                    color:
                        (isDark
                                ? RootBrandColors.mutedSage
                                : const Color(0xFF5E6F68))
                            .withValues(alpha: 0.7),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialog & Navigation Handlers ---

  Future<void> _editCustomElectrumNode(
    BuildContext context,
    WidgetRef ref,
  ) async {
    HapticFeedback.selectionClick();
    final currentUrl = ref.read(customNodeProvider).valueOrNull ?? '';
    final isDark = AppColors.isDark(context);

    final url = await showDialog<String?>(
      context: context,
      builder: (dialogContext) =>
          _CustomElectrumNodeDialog(initialUrl: currentUrl, isDark: isDark),
    );

    if (url == null || !context.mounted) {
      return;
    }

    try {
      final trimmed = url.trim();
      await ref
          .read(customNodeProvider.notifier)
          .setNodeUrl(trimmed.isEmpty ? null : trimmed);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Electrum node configuration updated.')),
      );
      // Force sync to refresh the wallet connection
      await ref
          .read(walletHomeControllerProvider.notifier)
          .sync(showLoading: true);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('FormatException: ', '')),
        ),
      );
    }
  }

  Future<void> _openSupport(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    await _openExternalLink(
      context,
      ref,
      AppConstants.supportUrl,
      copiedMessage: 'Support link copied.',
    );
  }

  Future<void> _openExternalLink(
    BuildContext context,
    WidgetRef ref,
    String url, {
    required String copiedMessage,
  }) async {
    final uri = Uri.parse(url);
    final launched = await ref
        .read(urlLauncherServiceProvider)
        .openExternalUrl(uri);
    if (launched || !context.mounted) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copiedMessage)));
  }

  Future<void> _deleteLocalWallet(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final isDark = AppColors.isDark(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RootRadius.lg),
          side: BorderSide(
            color: isDark
                ? RootBrandColors.borderPine
                : const Color(0xFFD7E3DC),
            width: 1.0,
          ),
        ),
        title: const Text(
          'Delete local wallet?',
          style: TextStyle(
            color: RootBrandColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This removes the wallet keys and cached data from this device. Funds can only be recovered using your 12-word recovery phrase.',
          style: TextStyle(
            color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? RootBrandColors.mutedSage
                    : const Color(0xFF5E6F68),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: RootBrandColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RootRadius.md),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Wallet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final authed = await _requireWalletResetAuth(context, ref);
    if (!authed || !context.mounted) {
      return;
    }

    await ref.read(resetWalletUsecaseProvider)();
    await (await ref.read(walletSnapshotCacheProvider.future)).clear();
    await ref.read(walletLabelsControllerProvider.notifier).clear();
    await ref.read(backupReminderProvider.notifier).clearBackupConfirmation();
    await ref.read(balancePrivacyProvider.notifier).clear();
    ref.invalidate(walletHomeControllerProvider);
    ref.invalidate(recoveryPhraseProvider);
    ref.invalidate(walletDiagnosticsControllerProvider);
    ref.invalidate(appStartControllerProvider);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local wallet deleted from this device.')),
    );
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.walletHome, (route) => false);
  }

  Future<bool> _requireWalletResetAuth(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final lock = ref.read(lockControllerProvider).valueOrNull;
    if (lock == null || !lock.isLockEnabled || !lock.hasPin) {
      return true;
    }

    final controller = ref.read(lockControllerProvider.notifier);
    var ok = await controller.requireReauth();
    if (!ok && context.mounted) {
      final pin = await showPinEntryDialog(
        context,
        title: 'Confirm wallet deletion',
        subtitle: 'Enter your PIN to delete this local wallet copy.',
        confirmLabel: 'Delete',
      );
      if (pin != null) {
        ok = await controller.verifyPin(pin);
      }
    }

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Authentication required.')));
    }
    return ok;
  }
}

// =============================================================================
// Settings UI Components
// =============================================================================

/// Section header label with subtle tracking and uppercase styling.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? RootBrandColors.mutedSage : const Color(0xFF6E8078),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Solid brand overview card displaying wallet security status, key status chips,
/// and live sync status without gradients or blur effects.
class _HealthOverviewCard extends StatelessWidget {
  const _HealthOverviewCard({
    required this.healthReady,
    required this.backupConfirmed,
    required this.isLockActive,
    required this.hideBalances,
    required this.flavor,
    required this.isSyncing,
    required this.isOffline,
    required this.updatedAgo,
    required this.onRefreshSync,
  });

  final bool healthReady;
  final bool backupConfirmed;
  final bool isLockActive;
  final bool hideBalances;
  final String flavor;
  final bool isSyncing;
  final bool isOffline;
  final String? updatedAgo;
  final VoidCallback onRefreshSync;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final cardBg = isDark
        ? RootBrandColors.deepForest
        : const Color(0xFFEBF4F0);
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFCCE0D7);
    final statusColor = healthReady
        ? RootBrandColors.pineGreen
        : RootBrandColors.amberAccent;

    return Container(
      padding: const EdgeInsets.all(RootSpacing.md + 2.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Shield + Title + Status Dot Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.18 : 0.14),
                  borderRadius: BorderRadius.circular(RootRadius.md),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  healthReady ? Icons.shield_rounded : Icons.shield_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: RootSpacing.sm + 2.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthReady
                          ? 'Wallet Protection: Solid'
                          : 'Protection Steps Incomplete',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      healthReady
                          ? 'Mnemonic backup confirmed & app lock configured.'
                          : 'Review recommended backup and app lock settings.',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RootSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RootSpacing.xs + 2.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.20 : 0.15),
                  borderRadius: BorderRadius.circular(RootRadius.pill),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      healthReady ? 'Secured' : 'Action',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.md),

          // Status Badges Wrap
          Wrap(
            spacing: RootSpacing.xs,
            runSpacing: RootSpacing.xs,
            children: [
              _SolidStatusChip(
                icon: Icons.shield_outlined,
                label: backupConfirmed ? 'Backup verified' : 'Backup needed',
                isPositive: backupConfirmed,
              ),
              _SolidStatusChip(
                icon: Icons.lock_outline_rounded,
                label: isLockActive ? 'App lock active' : 'App lock off',
                isPositive: isLockActive,
              ),
              _SolidStatusChip(
                icon: Icons.visibility_off_outlined,
                label: hideBalances ? 'Balances hidden' : 'Balances visible',
                isPositive: true,
              ),
              _SolidStatusChip(
                icon: Icons.public_rounded,
                label: '${flavor.toUpperCase()} Testnet',
                isPositive: true,
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.sm + 2.0),

          // Divider Line
          Divider(
            height: 1,
            color: isDark
                ? RootBrandColors.borderPine.withValues(alpha: 0.6)
                : const Color(0xFFD0DFD8),
          ),
          const SizedBox(height: RootSpacing.xs + 2.0),

          // Sync Status Line
          Row(
            children: [
              Icon(
                isSyncing
                    ? Icons.sync_rounded
                    : isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.check_circle_outline_rounded,
                size: 13,
                color: isSyncing
                    ? RootBrandColors.pineGreen
                    : isOffline
                    ? RootBrandColors.amberAccent
                    : (isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68)),
              ),
              const SizedBox(width: RootSpacing.xs),
              Expanded(
                child: Text(
                  isSyncing
                      ? 'Syncing blockchain data...'
                      : isOffline
                      ? 'Offline mode • Cached data'
                      : 'Blockchain synced ${updatedAgo ?? 'just now'}',
                  style: TextStyle(
                    color: isDark
                        ? RootBrandColors.mutedSage
                        : const Color(0xFF5E6F68),
                    fontSize: 11.5,
                  ),
                ),
              ),
              InkWell(
                onTap: onRefreshSync,
                borderRadius: BorderRadius.circular(RootRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RootSpacing.xs,
                    vertical: 2.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: RootBrandColors.pineGreen,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Sync',
                        style: TextStyle(
                          color: RootBrandColors.pineGreen,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact solid chip inside the health summary card.
class _SolidStatusChip extends StatelessWidget {
  const _SolidStatusChip({
    required this.icon,
    required this.label,
    required this.isPositive,
  });

  final IconData icon;
  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accentColor = isPositive
        ? (isDark ? RootBrandColors.mutedSage : const Color(0xFF436056))
        : RootBrandColors.amberAccent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RootSpacing.xs + 3.0,
        vertical: 3.5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? RootBrandColors.slatePine.withValues(alpha: 0.75)
            : const Color(0xFFDCE9E2),
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFC7DBD1),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isPositive
                  ? (isDark
                        ? RootBrandColors.warmIvory
                        : RootBrandColors.charcoalPine)
                  : RootBrandColors.amberAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium grouped card container for setting items.
class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 54,
                color: isDark
                    ? RootBrandColors.borderPine.withValues(alpha: 0.5)
                    : const Color(0xFFEEF3F0),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A clean setting row with leading icon container, title, subtitle,
/// optional status badge, and trailing action/chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeTone,
    this.iconTone,
    this.titleColor,
    this.trailingIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeTone;
  final Color? iconTone;
  final Color? titleColor;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = iconTone ?? RootBrandColors.pineGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RootSpacing.md,
            vertical: RootSpacing.sm + 4.0,
          ),
          child: Row(
            children: [
              // Icon Box
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(RootRadius.sm),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.25 : 0.20),
                    width: 1.0,
                  ),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: RootSpacing.md),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            titleColor ??
                            (isDark
                                ? RootBrandColors.warmIvory
                                : RootBrandColors.charcoalPine),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RootSpacing.xs),

              // Optional Status Badge
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RootSpacing.xs + 2.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeTone ?? RootBrandColors.pineGreen).withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(RootRadius.pill),
                    border: Border.all(
                      color: (badgeTone ?? RootBrandColors.pineGreen)
                          .withValues(alpha: 0.30),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      color: badgeTone ?? RootBrandColors.pineGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: RootSpacing.xs),
              ],

              // Trailing Icon
              Icon(
                trailingIcon ?? Icons.chevron_right_rounded,
                size: 20,
                color: isDark
                    ? RootBrandColors.mutedSage.withValues(alpha: 0.6)
                    : const Color(0xFFA0ACA5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Setting row with a switch toggle.
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = RootBrandColors.pineGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RootSpacing.md,
            vertical: RootSpacing.sm + 4.0,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(RootRadius.sm),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.25 : 0.20),
                    width: 1.0,
                  ),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: RootSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RootSpacing.xs),
              Switch.adaptive(
                value: value,
                activeTrackColor: RootBrandColors.pineGreen,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented selector control for ThemeMode: System, Light, Dark.
class _AppearanceSegmentedControl extends StatelessWidget {
  const _AppearanceSegmentedControl({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final containerBg = isDark
        ? RootBrandColors.slatePine
        : const Color(0xFFEDF3F0);
    final containerBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD4E2DC);

    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(RootRadius.md),
        border: Border.all(color: containerBorder, width: 1.0),
      ),
      child: Row(
        children: [
          for (final mode in ThemeMode.values)
            Expanded(
              child: _SegmentItem(
                mode: mode,
                isSelected: mode == currentMode,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final selectedBg = isDark
        ? RootBrandColors.deepForest
        : RootBrandColors.pureWhite;
    final selectedBorder = isDark
        ? RootBrandColors.pineGreen.withValues(alpha: 0.5)
        : RootBrandColors.pineGreen.withValues(alpha: 0.4);

    final activeColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final inactiveColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF6E8078);

    final (icon, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, 'System'),
      ThemeMode.light => (Icons.light_mode_rounded, 'Light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, 'Dark'),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(RootRadius.sm + 1.0),
          border: isSelected
              ? Border.all(color: selectedBorder, width: 1.0)
              : null,
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? RootBrandColors.pineGreen : inactiveColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomElectrumNodeDialog extends StatefulWidget {
  final String initialUrl;
  final bool isDark;

  const _CustomElectrumNodeDialog({
    required this.initialUrl,
    required this.isDark,
  });

  @override
  State<_CustomElectrumNodeDialog> createState() =>
      _CustomElectrumNodeDialogState();
}

class _CustomElectrumNodeDialogState extends State<_CustomElectrumNodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark
          ? RootBrandColors.nightPine
          : RootBrandColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RootRadius.lg),
        side: BorderSide(
          color: widget.isDark
              ? RootBrandColors.borderPine
              : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      title: Text(
        'Custom Electrum Node',
        style: TextStyle(
          color: widget.isDark
              ? RootBrandColors.warmIvory
              : RootBrandColors.charcoalPine,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specify a custom Electrum server URL (TCP or SSL).',
            style: TextStyle(
              color: widget.isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'tcp://testnet.aranguren.org:51001',
              hintStyle: TextStyle(
                color: widget.isDark
                    ? RootBrandColors.mutedSage.withValues(alpha: 0.5)
                    : const Color(0xFFA0ACA5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RootRadius.md),
              ),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: widget.isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
            ),
          ),
        ),
        if (widget.initialUrl.trim().isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text(
              'Reset Default',
              style: TextStyle(color: RootBrandColors.amberAccent),
            ),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: RootBrandColors.pineGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RootRadius.md),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save Node'),
        ),
      ],
    );
  }
}
