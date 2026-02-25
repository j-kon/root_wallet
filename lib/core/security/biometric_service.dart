abstract class BiometricService {
  Future<bool> isAvailable();
  Future<bool> authenticate({String reason = 'Authenticate'});
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
