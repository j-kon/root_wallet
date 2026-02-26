import 'package:local_auth/local_auth.dart';

abstract class BiometricService {
  Future<bool> isAvailable();
  Future<bool> authenticate({String reason = 'Authenticate'});
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? localAuth])
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> authenticate({String reason = 'Authenticate'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }
}

class NoopBiometricService implements BiometricService {
  const NoopBiometricService();

  @override
  Future<bool> authenticate({String reason = 'Authenticate'}) async {
    return false;
  }

  @override
  Future<bool> isAvailable() async {
    return false;
  }
}
