import 'dart:convert';

import 'package:root_wallet/core/security/secure_storage.dart';

class PinLockService {
  PinLockService(this._secureStorage);

  static const _pinKey = 'security.pin_hash';
  final SecureStorage _secureStorage;

  Future<void> clearPin() {
    return _secureStorage.delete(key: _pinKey);
  }

  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: _hash(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _secureStorage.read(key: _pinKey);
    if (hash == null) {
      return false;
    }
    return hash == _hash(pin);
  }

  String _hash(String value) {
    final bytes = utf8.encode(value);
    return base64Url.encode(bytes);
  }
}
