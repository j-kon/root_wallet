import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/app/theme/theme_mode_provider.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = Theme.of(context).platform;
    final useCupertino = platform == TargetPlatform.iOS;
    final shadow = AppColors.shadowOf(context);
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final walletState = ref.watch(walletControllerProvider).valueOrNull;
    final lockState = ref.watch(lockControllerProvider).valueOrNull;
    final backupConfirmed =
        ref.watch(backupReminderProvider).valueOrNull ?? false;
    final hideBalances = ref.watch(balancePrivacyProvider).valueOrNull ?? false;
    final env = ref.watch(appEnvProvider);
    final healthReady =
        backupConfirmed &&
        (lockState?.isLockEnabled ?? false) &&
        (lockState?.hasPin ?? false);

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        children: [
          Container(
            padding: EdgeInsets.all(
              context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: healthReady
                    ? [AppColors.secondary, AppColors.primary]
                    : [Colors.brown.shade700, AppColors.warning],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthReady
                      ? 'Wallet health looks strong.'
                      : 'A few protection steps still need attention.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  walletState == null
                      ? 'Security posture and sync health will appear here when wallet data is ready.'
                      : walletState.isSyncing
                      ? 'Wallet data is syncing against the public testnet network.'
                      : walletState.isOffline
                      ? 'Offline mode active. Cached wallet data was last updated ${AppDateTime.updatedAgo(walletState.lastSyncedAt)}.'
                      : 'Last synced ${AppDateTime.updatedAgo(walletState.lastSyncedAt)}. Review privacy, backup, and support controls below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StatusPill(
                      icon: Icons.shield_outlined,
                      label: backupConfirmed
                          ? 'Backup verified'
                          : 'Backup needed',
                    ),
                    _StatusPill(
                      icon: Icons.lock_outline_rounded,
                      label: (lockState?.isLockEnabled ?? false)
                          ? 'App lock on'
                          : 'App lock off',
                    ),
                    _StatusPill(
                      icon: Icons.visibility_off_outlined,
                      label: hideBalances
                          ? 'Balances hidden'
                          : 'Balances visible',
                    ),
                    _StatusPill(
                      icon: Icons.language_rounded,
                      label: '${env.flavor.toUpperCase()} flavor',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsPanel(
            title: 'Appearance',
            subtitle: 'Choose how the wallet should look on this device.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 420 ? 3 : 2;
                final gap = AppSpacing.sm;
                final optionWidth =
                    (constraints.maxWidth - (gap * (columns - 1))) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final option in ThemeMode.values)
                      SizedBox(
                        width: optionWidth,
                        child: _ThemeModeOption(
                          mode: option,
                          selected: option == themeMode,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(option),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsPanel(
            title: 'Protection',
            subtitle: 'Controls that affect wallet safety and privacy.',
            child: Column(
              children: [
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.lock_shield
                      : Icons.security_rounded,
                  title: 'Security',
                  subtitle: (lockState?.isLockEnabled ?? false)
                      ? 'PIN and unlock controls are configured.'
                      : 'Configure app lock, biometrics, and auto-lock.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.security),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsTile(
                  icon: Icons.vpn_key_outlined,
                  title: 'Recovery phrase',
                  subtitle: backupConfirmed
                      ? 'Backup has been reviewed and confirmed.'
                      : 'Complete your backup to protect wallet access.',
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.backupSeed,
                    arguments: const BackupSeedPageArgs(
                      requireReauth: true,
                      isOnboardingFlow: false,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsToggleTile(
                  icon: useCupertino
                      ? CupertinoIcons.eye_slash
                      : Icons.visibility_off_outlined,
                  title: 'Hide balances',
                  subtitle: 'Mask amounts on overview and transaction screens.',
                  value: hideBalances,
                  onChanged: (value) => ref
                      .read(balancePrivacyProvider.notifier)
                      .setHidden(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsPanel(
            title: 'Wallet operations',
            subtitle: 'Maintenance and lifecycle actions.',
            child: Column(
              children: [
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.refresh_circled
                      : Icons.sync_rounded,
                  title: 'Refresh wallet data',
                  subtitle: 'Force a sync of balances, address, and activity.',
                  onTap: () async {
                    await ref
                        .read(walletHomeControllerProvider.notifier)
                        .sync();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wallet sync requested.')),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.add_circled
                      : Icons.add_circle_outline,
                  title: 'Create wallet',
                  subtitle: 'Start a fresh wallet setup flow.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.createWallet),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.arrow_2_circlepath
                      : Icons.restore_rounded,
                  title: 'Restore wallet',
                  subtitle: 'Import an existing recovery phrase.',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.restoreWallet),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsPanel(
            title: 'Help and app info',
            subtitle: 'Support, app information, and technical context.',
            child: Column(
              children: [
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.question_circle
                      : Icons.help_outline_rounded,
                  title: 'Help / Support',
                  subtitle: 'Open support or copy the support URL.',
                  onTap: () => _openSupport(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.compass
                      : Icons.explore_outlined,
                  title: 'Public testnet explorer',
                  subtitle:
                      'Open mempool.space/testnet or copy the explorer URL.',
                  onTap: () => _openExternalLink(
                    context,
                    ref,
                    AppConstants.testnetExplorerBaseUrl,
                    copiedMessage: 'Explorer URL copied.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsTile(
                  icon: useCupertino
                      ? CupertinoIcons.info_circle
                      : Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'Architecture, environment, and wallet principles.',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupport(BuildContext context, WidgetRef ref) async {
    await _openExternalLink(
      context,
      ref,
      AppConstants.supportUrl,
      copiedMessage: 'Support URL copied.',
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
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
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
      ).withValues(alpha: AppColors.isDark(context) ? 0.60 : 0.95),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => onChanged(!value),
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
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.md),
          tint: selected
              ? primary.withValues(
                  alpha: AppColors.isDark(context) ? 0.20 : 0.12,
                )
              : AppColors.glassSurfaceOf(
                  context,
                ).withValues(alpha: AppColors.isDark(context) ? 0.48 : 0.92),
          borderColor: selected
              ? primary.withValues(alpha: 0.42)
              : AppColors.glassBorderOf(context),
          highlightOpacity: 0.04,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                mode.icon,
                color: selected ? primary : textSecondary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  mode.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? textPrimary : textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      tint: Colors.white.withValues(alpha: 0.12),
      borderColor: Colors.white.withValues(alpha: 0.10),
      shadowColor: Colors.transparent,
      highlightOpacity: 0.03,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
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
