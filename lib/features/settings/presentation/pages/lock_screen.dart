import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const _pinLength = 6;
  String _enteredPin = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricUnlock();
    });
  }

  Future<void> _tryBiometricUnlock() async {
    final lock = ref.read(lockControllerProvider).valueOrNull;
    if (lock == null || !lock.isLocked) {
      return;
    }
    if (!lock.isBiometricsEnabled || !lock.isBiometricAvailable) {
      return;
    }
    await ref
        .read(lockControllerProvider.notifier)
        .authenticateWithBiometrics();
  }

  Future<void> _submitPin() async {
    final pin = _enteredPin;
    setState(() {
      _enteredPin = '';
    });
    await ref.read(lockControllerProvider.notifier).verifyPin(pin);
  }

  void _onDigitTap(String digit, AppLockState lock) {
    if (lock.isInCooldown || lock.isBusy) {
      return;
    }
    if (_enteredPin.length >= _pinLength) {
      return;
    }

    setState(() {
      _enteredPin += digit;
    });

    if (_enteredPin.length == _pinLength) {
      _submitPin();
    }
  }

  void _onBackspace(AppLockState lock) {
    if (lock.isInCooldown || lock.isBusy || _enteredPin.isEmpty) {
      return;
    }
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockAsync = ref.watch(lockControllerProvider);

    return PopScope(
      canPop: false,
      child: AppScaffold(
        body: lockAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('Unable to unlock app')),
          data: (data) {
            if (!data.isLocked) {
              return const SizedBox.shrink();
            }

            final cooldownText = data.isInCooldown
                ? 'Too many attempts. Try again in ${data.cooldownRemainingSeconds}s.'
                : null;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(AppRadius.lg + 6),
                    tint: AppColors.glassSurfaceStrongOf(context).withValues(
                      alpha: AppColors.isDark(context) ? 0.68 : 0.96,
                    ),
                    highlightOpacity: 0.05,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.glassSurfaceOf(context).withValues(
                              alpha: AppColors.isDark(context) ? 0.62 : 0.92,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.glassBorderOf(context),
                            ),
                          ),
                          child: Icon(
                            Icons.lock_open_rounded,
                            color: AppColors.primaryOf(context),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Unlock Root Wallet',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          cooldownText ??
                              data.message ??
                              'Enter your 6-digit PIN to continue.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        GlassSurface(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          tint: AppColors.glassSurfaceOf(context).withValues(
                            alpha: AppColors.isDark(context) ? 0.54 : 0.90,
                          ),
                          shadowColor: Colors.transparent,
                          highlightOpacity: 0.03,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(_pinLength, (
                              index,
                            ) {
                              final filled = index < _enteredPin.length;
                              return Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.4),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (data.isBusy)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.xl,
                            ),
                            child: CircularProgressIndicator(),
                          ),
                        if (!data.isBusy)
                          _PinPad(
                            onDigitTap: (digit) => _onDigitTap(digit, data),
                            onBackspace: () => _onBackspace(data),
                            onBiometricTap: data.isBiometricAvailable &&
                                    data.isBiometricsEnabled
                                ? _tryBiometricUnlock
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.onDigitTap,
    required this.onBackspace,
    this.onBiometricTap,
  });

  final ValueChanged<String> onDigitTap;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometricTap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_PinKeyData>>[
      [
        const _PinKeyData(label: '1'),
        const _PinKeyData(label: '2'),
        const _PinKeyData(label: '3'),
      ],
      [
        const _PinKeyData(label: '4'),
        const _PinKeyData(label: '5'),
        const _PinKeyData(label: '6'),
      ],
      [
        const _PinKeyData(label: '7'),
        const _PinKeyData(label: '8'),
        const _PinKeyData(label: '9'),
      ],
      [
        _PinKeyData(icon: Icons.fingerprint_rounded, onTap: onBiometricTap),
        const _PinKeyData(label: '0'),
        _PinKeyData(icon: Icons.backspace_outlined, onTap: onBackspace),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalGap =
            constraints.maxWidth < 280 ? AppSpacing.sm : AppSpacing.md;
        final keyWidth = math.min(
          84.0,
          (constraints.maxWidth - (horizontalGap * 2)) / 3,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final key in row) ...[
                    _PinKey(
                      width: keyWidth,
                      label: key.label,
                      icon: key.icon,
                      onTap: key.onTap ??
                          (key.label == null
                              ? null
                              : () => onDigitTap(key.label!)),
                    ),
                    if (key != row.last) SizedBox(width: horizontalGap),
                  ],
                ],
              ),
              if (row != rows.last) const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.width, this.label, this.icon, this.onTap});

  final double width;
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 62,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            tint: AppColors.glassSurfaceOf(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.56 : 0.92),
            highlightOpacity: 0.03,
            shadowColor: Colors.transparent,
            child: Center(
              child: label != null
                  ? Text(label!, style: Theme.of(context).textTheme.titleLarge)
                  : Icon(icon, color: AppColors.textPrimaryOf(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeyData {
  const _PinKeyData({this.label, this.icon, this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
}
