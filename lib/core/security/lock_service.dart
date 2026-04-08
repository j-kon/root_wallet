import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';

class LockService {
  LockService({
    required PinLockService pinLockService,
    required BiometricService biometricService,
  }) : _pinLockService = pinLockService,
       _biometricService = biometricService;

  final PinLockService _pinLockService;
  final BiometricService _biometricService;

  Future<bool> authenticateBiometric({String reason = 'Unlock Root Wallet'}) {
    return _biometricService.authenticate(reason: reason);
  }

  Future<void> clearPin() {
    return _pinLockService.clearPin();
  }

  Future<bool> hasPin() {
    return _pinLockService.hasPin();
  }

  Future<bool> isBiometricAvailable() {
    return _biometricService.isAvailable();
  }

  Future<void> setPin(String pin) {
    return _pinLockService.setPin(pin);
  }

  Future<bool> verifyPin(String pin) {
    return _pinLockService.verifyPin(pin);
  }
}
