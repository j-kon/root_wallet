import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';

void main() {
  group('PinLockService', () {
    test('stores hashed pin and verifies it correctly', () async {
      final storage = InMemorySecureStorage();
      final service = PinLockService(storage);

      await service.setPin('123456');

      expect(await storage.read(key: 'security.pin_hash'), isNot('123456'));
      expect(await storage.read(key: 'security.pin_salt'), isNotEmpty);
      expect(await service.verifyPin('123456'), isTrue);
      expect(await service.verifyPin('654321'), isFalse);
    });

    test('clears stored pin state', () async {
      final storage = InMemorySecureStorage();
      final service = PinLockService(storage);

      await service.setPin('123456');
      await service.clearPin();

      expect(await service.hasPin(), isFalse);
      expect(await service.verifyPin('123456'), isFalse);
    });
  });
}
