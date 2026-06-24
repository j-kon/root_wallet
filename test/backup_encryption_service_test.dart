import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService', () {
    const mnemonic = 'about check dynamic elegant first health dynamic dynamic dynamic dynamic dynamic dynamic';
    const plainText = '{"labels": {"tb1qaddress": "Test Label"}, "transactions": {}}';

    test('deriveKey derives identical keys for same mnemonic with different spacing', () {
      final key1 = BackupEncryptionService.deriveKey(mnemonic);
      final key2 = BackupEncryptionService.deriveKey('  $mnemonic  ');
      final key3 = BackupEncryptionService.deriveKey(mnemonic.replaceAll(RegExp(r'\s+'), '   '));

      expect(key1.bytes, equals(key2.bytes));
      expect(key1.bytes, equals(key3.bytes));
    });

    test('encrypt and decrypt round-trip correctly', () {
      final encrypted = BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(plainText)));

      final decrypted = BackupEncryptionService.decrypt(
        encryptedCombinedBase64: encrypted,
        mnemonic: mnemonic,
      );

      expect(decrypted, equals(plainText));
    });

    test('decrypt throws on invalid format or mismatched mnemonic', () {
      final encrypted = BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      // Mismatched mnemonic
      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: encrypted,
          mnemonic: 'wrong mnemonic word list here dynamic dynamic dynamic dynamic dynamic dynamic dynamic',
        ),
        throwsArgumentError,
      );

      // Too short payload
      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: 'aaaa',
          mnemonic: mnemonic,
        ),
        throwsFormatException,
      );

      // Non-base64 payload
      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: 'invalid_base64_payload_here!!!',
          mnemonic: mnemonic,
        ),
        throwsA(anything),
      );
    });
  });
}
