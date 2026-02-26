import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/layout.dart';
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
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: lockAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(child: Text('Unable to unlock app')),
            data: (data) {
              if (!data.isLocked) {
                return const SizedBox.shrink();
              }

              final cooldownText = data.isInCooldown
                  ? 'Too many attempts. Try again in ${data.cooldownRemainingSeconds}s.'
                  : null;

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Unlock Root Wallet',
                      style: Theme.of(context).textTheme.headlineSmall,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_pinLength, (index) {
                        final filled = index < _enteredPin.length;
                        return Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (data.isBusy) const CircularProgressIndicator(),
                    if (!data.isBusy)
                      Expanded(
                        child: _PinPad(
                          onDigitTap: (digit) => _onDigitTap(digit, data),
                          onBackspace: () => _onBackspace(data),
                          onBiometricTap:
                              data.isBiometricAvailable &&
                                  data.isBiometricsEnabled
                              ? _tryBiometricUnlock
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
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
    final digits = <String>['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final digit in digits)
              _PinKey(label: digit, onTap: () => onDigitTap(digit)),
            _PinKey(icon: Icons.fingerprint_rounded, onTap: onBiometricTap),
            _PinKey(label: '0', onTap: () => onDigitTap('0')),
            _PinKey(icon: Icons.backspace_outlined, onTap: onBackspace),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 62,
      child: OutlinedButton(
        onPressed: onTap,
        child: label != null
            ? Text(label!, style: Theme.of(context).textTheme.titleLarge)
            : Icon(icon),
      ),
    );
  }
}
