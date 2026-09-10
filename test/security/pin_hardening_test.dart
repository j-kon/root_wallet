import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';

void main() {
  group('PinLockService Hardening & Argon2id KDF', () {
    late InMemorySecureStorage storage;
    late PinLockService service;

    setUp(() {
      storage = InMemorySecureStorage();
      service = PinLockService(storage);
    });

    test('setPin generates versioned Argon2id verifier envelope', () async {
      await service.setPin('123456');

      expect(await service.hasPin(), isTrue);
      final storedVerifier = await storage.read(key: 'security.pin_hash');
      expect(storedVerifier, isNotNull);
      expect(storedVerifier!.startsWith(r'$argon2id$v=1$m=16384,t=3,p=1$'), isTrue);

      // Verify legacy salt key is deleted
      expect(await storage.read(key: 'security.pin_salt'), isNull);
    });

    test('verifyPin succeeds with correct PIN and fails with incorrect PIN', () async {
      await service.setPin('654321');

      expect(await service.verifyPin('654321'), isTrue);
      expect(await service.verifyPin('123456'), isFalse);
      expect(await service.verifyPin('654320'), isFalse);
      expect(await service.verifyPin(''), isFalse);
    });

    test('decoy PIN uses Argon2id and verifies independently', () async {
      await service.setPin('111111');
      await service.setDecoyPin('999999');

      expect(await service.hasDecoyPin(), isTrue);
      final decoyVerifier = await storage.read(key: 'security.decoy_pin_hash');
      expect(decoyVerifier!.startsWith(r'$argon2id$v=1$m=16384,t=3,p=1$'), isTrue);

      expect(await service.verifyDecoyPin('999999'), isTrue);
      expect(await service.verifyDecoyPin('111111'), isFalse);
      expect(await service.verifyPin('999999'), isFalse);
      expect(await service.verifyPin('111111'), isTrue);
    });

    test('transparently migrates legacy salted SHA-256 verifier to Argon2id', () async {
      const pin = '888888';
      const salt = 'legacy_salt_random_value';
      final legacyHash = crypto.sha256.convert(utf8.encode('$salt::$pin')).toString();

      // Seed storage with legacy format
      await storage.write(key: 'security.pin_salt', value: salt);
      await storage.write(key: 'security.pin_hash', value: legacyHash);

      expect(await service.hasPin(), isTrue);

      // Verifying with wrong PIN does not migrate
      expect(await service.verifyPin('000000'), isFalse);
      expect(await storage.read(key: 'security.pin_hash'), equals(legacyHash));

      // Verifying with correct PIN succeeds AND migrates to Argon2id
      final ok = await service.verifyPin(pin);
      expect(ok, isTrue);

      final migratedVerifier = await storage.read(key: 'security.pin_hash');
      expect(migratedVerifier, isNotNull);
      expect(migratedVerifier!.startsWith(r'$argon2id$v=1$m=16384,t=3,p=1$'), isTrue);
      expect(await storage.read(key: 'security.pin_salt'), isNull);

      // Verify migrated verifier still validates correctly
      expect(await service.verifyPin(pin), isTrue);
    });

    test('progressive delay ladder enforces escalating delays', () async {
      expect(service.delayForAttempts(1), equals(0));
      expect(service.delayForAttempts(4), equals(0));
      expect(service.delayForAttempts(5), equals(30));
      expect(service.delayForAttempts(6), equals(60));
      expect(service.delayForAttempts(7), equals(300));
      expect(service.delayForAttempts(8), equals(900));
      expect(service.delayForAttempts(9), equals(1800));
      expect(service.delayForAttempts(10), equals(3600));
      expect(service.delayForAttempts(20), equals(3600));
    });

    test('persistent lockout records failures and cooldown in secure storage', () async {
      expect(await service.getFailedAttempts(), equals(0));
      expect(await service.getRemainingCooldownSeconds(), equals(0));

      // Fail 4 times (no cooldown yet)
      for (var i = 1; i <= 4; i++) {
        final attempts = await service.recordFailedAttempt();
        expect(attempts, equals(i));
        expect(await service.getRemainingCooldownSeconds(), equals(0));
      }

      // 5th failure triggers 30s cooldown
      final attempts = await service.recordFailedAttempt();
      expect(attempts, equals(5));
      final remaining = await service.getRemainingCooldownSeconds();
      expect(remaining, greaterThanOrEqualTo(28));
      expect(remaining, lessThanOrEqualTo(30));

      // Reset clears both failure count and cooldown
      await service.resetLockout();
      expect(await service.getFailedAttempts(), equals(0));
      expect(await service.getRemainingCooldownSeconds(), equals(0));
    });

    test('corrupted or malformed verifiers fail closed without crashing', () async {
      await storage.write(key: 'security.pin_hash', value: r'$argon2id$v=1$invalid');
      expect(await service.verifyPin('123456'), isFalse);

      await storage.write(key: 'security.pin_hash', value: 'completely_corrupt_non_argon_value');
      expect(await service.verifyPin('123456'), isFalse);
    });
  });
}
