import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/core/widgets/pin_entry_dialog.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockAsync = ref.watch(lockControllerProvider);
    final controller = ref.read(lockControllerProvider.notifier);
    final decoyPinAsync = ref.watch(decoyPinProvider);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Security',
      body: lockAsync.when(
        loading: () => const Loading(label: 'Loading security settings...'),
        error: (error, stackTrace) =>
            const Center(child: Text('Unable to load security settings.')),
        data: (lock) {
          final isSecured = lock.isLockEnabled && lock.hasPin;
          final statusLabel = lock.isLockEnabled
              ? 'Protected by app lock'
              : 'App lock is currently disabled';
          final subtitle = lock.isLockEnabled
              ? 'Biometrics, auto-lock timing, and PIN posture are active.'
              : 'Enable lock protection to secure wallet data when leaving the app.';

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              RootSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing,
            ),
            children: [
              // 1. Dynamic Security Posture Shield Hero Card
              _SecurityPostureHeroCard(
                isSecured: isSecured,
                isLocked: lock.isLocked,
                isInCooldown: lock.isInCooldown,
                statusLabel: statusLabel,
                subtitle: subtitle,
                hasPin: lock.hasPin,
                isBiometricsEnabled: lock.isBiometricsEnabled,
                autoLockLabel: lock.autoLockOption.label,
                hasDecoyPin: decoyPinAsync.valueOrNull ?? false,
              ),

              if (lock.message != null) ...[
                const SizedBox(height: RootSpacing.md),
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

              const SizedBox(height: RootSpacing.lg),

              // 2. Access Controls Section
              _SecuritySectionHeader(
                title: 'Access controls',
                subtitle: 'Configure authentication required to reopen the wallet.',
              ),
              const SizedBox(height: RootSpacing.xs),
              _SecuritySectionContainer(
                children: [
                  _SecurityToggleTile(
                    icon: CupertinoIcons.lock_shield_fill,
                    title: 'Enable app lock',
                    subtitle: 'Require biometric or PIN authentication on resume.',
                    value: lock.isLockEnabled,
                    onChanged: (enabled) async {
                      HapticFeedback.selectionClick();
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
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark
                        ? RootBrandColors.borderPine
                        : const Color(0xFFD7E3DC),
                  ),
                  _SecurityToggleTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'Enable biometrics',
                    subtitle: lock.isBiometricAvailable
                        ? 'Unlock instantly with Face ID or Touch ID before PIN.'
                        : 'Biometric authentication is not supported or enrolled.',
                    value: lock.isBiometricsEnabled,
                    enabled: lock.isLockEnabled && lock.isBiometricAvailable,
                    onChanged: lock.isLockEnabled && lock.isBiometricAvailable
                        ? (value) {
                            HapticFeedback.selectionClick();
                            controller.setBiometricsEnabled(value);
                          }
                        : (_) {},
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark
                        ? RootBrandColors.borderPine
                        : const Color(0xFFD7E3DC),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(RootSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? RootBrandColors.slatePine
                                    : const Color(0xFFE8EFEA),
                                borderRadius: BorderRadius.circular(
                                  RootRadius.md,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? RootBrandColors.borderPine
                                      : const Color(0xFFD7E3DC),
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                              ),
                            ),
                            const SizedBox(width: RootSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto-lock timing',
                                    style: TextStyle(
                                      color: isDark
                                          ? RootBrandColors.warmIvory
                                          : RootBrandColors.charcoalPine,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lock when leaving the app after a chosen inactivity period.',
                                    style: TextStyle(
                                      color: isDark
                                          ? RootBrandColors.mutedSage
                                          : const Color(0xFF5E6F68),
                                      fontSize: 12.0,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RootSpacing.md),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? RootBrandColors.slatePine
                                : const Color(0xFFF6F8F7),
                            borderRadius: BorderRadius.circular(RootRadius.md),
                            border: Border.all(
                              color: isDark
                                  ? RootBrandColors.borderPine
                                  : const Color(0xFFD7E3DC),
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<AutoLockOption>(
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              dropdownColor: isDark
                                  ? RootBrandColors.nightPine
                                  : RootBrandColors.pureWhite,
                              initialValue: lock.autoLockOption,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                              ),
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              onChanged: lock.isLockEnabled
                                  ? (value) {
                                      if (value == null) return;
                                      HapticFeedback.selectionClick();
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: RootSpacing.lg),

              // 3. PIN Management Section
              _SecuritySectionHeader(
                title: 'PIN management',
                subtitle: 'Manage the primary unlock credential and duress security.',
              ),
              const SizedBox(height: RootSpacing.xs),
              _SecuritySectionContainer(
                children: [
                  _SecurityActionTile(
                    icon: Icons.password_rounded,
                    title: lock.hasPin ? 'Change PIN' : 'Set PIN',
                    subtitle: '6-digit high-entropy master access PIN',
                    badgeText: lock.hasPin ? 'Configured' : 'Missing',
                    badgeColor: lock.hasPin
                        ? RootBrandColors.pineGreen
                        : RootBrandColors.amberAccent,
                    onTap: () async {
                      final pin = await _promptPinSetup(context);
                      if (pin == null) return;
                      await controller.setPin(pin);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN updated.')),
                      );
                    },
                  ),
                  if (lock.hasPin) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? RootBrandColors.borderPine
                          : const Color(0xFFD7E3DC),
                    ),
                    decoyPinAsync.when(
                      data: (hasDecoy) => _SecurityActionTile(
                        icon: Icons.shield_outlined,
                        title: hasDecoy
                            ? 'Change Duress PIN'
                            : 'Set Duress PIN',
                        subtitle:
                            'Under duress, enter this PIN to unlock a secondary decoy wallet.',
                        badgeText: hasDecoy ? 'Active' : 'Optional',
                        badgeColor: hasDecoy
                            ? RootBrandColors.pineGreen
                            : RootBrandColors.mutedSage,
                        onTap: () async {
                          final pin = await _promptPinSetup(context);
                          if (pin == null) return;
                          final lockService = ref.read(lockServiceProvider);
                          final isSame = await lockService.verifyPin(pin);
                          if (isSame) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Duress PIN cannot be the same as the main PIN.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          await ref
                              .read(decoyPinProvider.notifier)
                              .setDecoyPin(pin);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                hasDecoy
                                    ? 'Duress PIN updated.'
                                    : 'Duress PIN set.',
                              ),
                            ),
                          );
                        },
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    if (decoyPinAsync.valueOrNull == true) ...[
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? RootBrandColors.borderPine
                            : const Color(0xFFD7E3DC),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RootSpacing.md,
                          vertical: RootSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: MagneticPressable(
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  backgroundColor: isDark
                                      ? RootBrandColors.nightPine
                                      : RootBrandColors.pureWhite,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      RootRadius.lg,
                                    ),
                                    side: BorderSide(
                                      color: isDark
                                          ? RootBrandColors.borderPine
                                          : const Color(0xFFD7E3DC),
                                      width: 1.0,
                                    ),
                                  ),
                                  title: const Text('Clear Duress PIN?'),
                                  content: const Text(
                                    'This will disable the decoy wallet lock screen bypass.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: RootBrandColors.error,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: const Text('Clear'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) {
                                return;
                              }
                              await ref
                                  .read(decoyPinProvider.notifier)
                                  .clearDecoyPin();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Duress PIN cleared.'),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: RootBrandColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  RootRadius.md,
                                ),
                                border: Border.all(
                                  color: RootBrandColors.error.withValues(alpha: 0.4),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.no_accounts_rounded,
                                    size: 16,
                                    color: RootBrandColors.error,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Clear Duress PIN',
                                    style: TextStyle(
                                      color: RootBrandColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (lock.isLockEnabled) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? RootBrandColors.borderPine
                          : const Color(0xFFD7E3DC),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(RootSpacing.md),
                      child: MagneticPressable(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          controller.lockNow();
                        },
                        child: Container(
                          width: double.infinity,
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_clock_outlined,
                                size: 18,
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lock now',
                                style: TextStyle(
                                  color: isDark
                                      ? RootBrandColors.warmIvory
                                      : RootBrandColors.charcoalPine,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _promptPinSetup(BuildContext context) async {
    final first = await _promptPin(context, title: 'Set 6-digit PIN');
    if (first == null) return null;
    if (!context.mounted) return null;

    final second = await _promptPin(context, title: 'Confirm PIN');
    if (second == null) return null;

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
    return showPinEntryDialog(
      context,
      title: title,
      subtitle: 'Choose a 6-digit PIN that you can remember confidently.',
      confirmLabel: 'Save',
    );
  }
}

// ---------------------------------------------------------------------------
// Redesigned Solid Posture Hero Card
// ---------------------------------------------------------------------------

class _SecurityPostureHeroCard extends StatelessWidget {
  const _SecurityPostureHeroCard({
    required this.isSecured,
    required this.isLocked,
    required this.isInCooldown,
    required this.statusLabel,
    required this.subtitle,
    required this.hasPin,
    required this.isBiometricsEnabled,
    required this.autoLockLabel,
    required this.hasDecoyPin,
  });

  final bool isSecured;
  final bool isLocked;
  final bool isInCooldown;
  final String statusLabel;
  final String subtitle;
  final bool hasPin;
  final bool isBiometricsEnabled;
  final String autoLockLabel;
  final bool hasDecoyPin;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final statusColor = isInCooldown
        ? RootBrandColors.error
        : isSecured
            ? RootBrandColors.pineGreen
            : RootBrandColors.amberAccent;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.all(
        context.isCompactWidth ? RootSpacing.md : RootSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(RootRadius.md),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.36),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  isInCooldown
                      ? Icons.warning_amber_rounded
                      : isSecured
                          ? CupertinoIcons.checkmark_shield_fill
                          : CupertinoIcons.shield_slash_fill,
                  size: 22,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: RootSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.mutedSage
                            : const Color(0xFF5E6F68),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.md),
          Wrap(
            spacing: RootSpacing.xs,
            runSpacing: RootSpacing.xs,
            children: [
              _SecurityPill(
                icon: Icons.pin_outlined,
                label: hasPin ? 'PIN set' : 'PIN not set',
                tone: hasPin
                    ? RootBrandColors.pineGreen
                    : RootBrandColors.amberAccent,
              ),
              _SecurityPill(
                icon: Icons.fingerprint_rounded,
                label: isBiometricsEnabled ? 'Biometrics on' : 'Biometrics off',
                tone: isBiometricsEnabled
                    ? RootBrandColors.pineGreen
                    : RootBrandColors.mutedSage,
              ),
              _SecurityPill(
                icon: Icons.timer_outlined,
                label: autoLockLabel,
                tone: RootBrandColors.pineGreen,
              ),
              if (hasDecoyPin)
                _SecurityPill(
                  icon: Icons.shield_outlined,
                  label: 'Duress mode ready',
                  tone: RootBrandColors.pineGreen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityPill extends StatelessWidget {
  const _SecurityPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.slatePine : const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
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
              color: tone,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            icon,
            size: 13,
            color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Containers and Layout Components
// ---------------------------------------------------------------------------

class _SecuritySectionHeader extends StatelessWidget {
  const _SecuritySectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _SecuritySectionContainer extends StatelessWidget {
  const _SecuritySectionContainer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SecurityToggleTile extends StatelessWidget {
  const _SecurityToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.all(RootSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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
              child: Icon(
                icon,
                size: 19,
                color: isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine,
              ),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68),
                      fontSize: 12.0,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RootSpacing.sm),
            Switch.adaptive(
              value: value,
              activeTrackColor: RootBrandColors.pineGreen,
              activeThumbColor: RootBrandColors.pureWhite,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityActionTile extends StatelessWidget {
  const _SecurityActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return MagneticPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RootSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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
              child: Icon(
                icon,
                size: 19,
                color: isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine,
              ),
            ),
            const SizedBox(width: RootSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isDark
                                ? RootBrandColors.warmIvory
                                : RootBrandColors.charcoalPine,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? RootBrandColors.pineGreen)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              RootRadius.pill,
                            ),
                            border: Border.all(
                              color: (badgeColor ?? RootBrandColors.pineGreen)
                                  .withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              color: badgeColor ?? RootBrandColors.pineGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68),
                      fontSize: 12.0,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RootSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
            ),
          ],
        ),
      ),
    );
  }
}
