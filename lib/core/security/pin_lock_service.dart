import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:root_wallet/core/security/secure_storage.dart';

class PinLockService {
  PinLockService(this._secureStorage);

  static const _pinHashKey = 'security.pin_hash';
  static const _pinSaltKey = 'security.pin_salt';
  static const _decoyPinHashKey = 'security.decoy_pin_hash';
  static const _decoyPinSaltKey = 'security.decoy_pin_salt';
  final SecureStorage _secureStorage;

  Future<void> clearPin() {
    return Future.wait([
      _secureStorage.delete(key: _pinHashKey),
      _secureStorage.delete(key: _pinSaltKey),
    ]);
  }

  Future<bool> hasPin() async {
    final hash = await _secureStorage.read(key: _pinHashKey);
    final salt = await _secureStorage.read(key: _pinSaltKey);
    return hash != null && salt != null && hash.isNotEmpty && salt.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: salt);
    await _secureStorage.write(key: _pinHashKey, value: hash);
  }

  Future<void> clearDecoyPin() {
    return Future.wait([
      _secureStorage.delete(key: _decoyPinHashKey),
      _secureStorage.delete(key: _decoyPinSaltKey),
    ]);
  }

  Future<bool> hasDecoyPin() async {
    final hash = await _secureStorage.read(key: _decoyPinHashKey);
    final salt = await _secureStorage.read(key: _decoyPinSaltKey);
    return hash != null && salt != null && hash.isNotEmpty && salt.isNotEmpty;
  }

  Future<void> setDecoyPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _secureStorage.write(key: _decoyPinSaltKey, value: salt);
    await _secureStorage.write(key: _decoyPinHashKey, value: hash);
  }

  Future<bool> verifyDecoyPin(String pin) async {
    final hash = await _secureStorage.read(key: _decoyPinHashKey);
    final salt = await _secureStorage.read(key: _decoyPinSaltKey);
    if (hash == null || salt == null) {
      return false;
    }
    return hash == _hash(pin, salt);
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _secureStorage.read(key: _pinHashKey);
    final salt = await _secureStorage.read(key: _pinSaltKey);
    if (hash == null || salt == null) {
      return false;
    }
    return hash == _hash(pin, salt);
  }

  String _generateSalt({int length = 16}) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }
}
