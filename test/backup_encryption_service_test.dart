import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/security/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService V2 (AES-256-GCM)', () {
    const mnemonic =
        'about check dynamic elegant first health dynamic dynamic dynamic dynamic dynamic dynamic';
    const plainText =
        '{"labels": {"tb1qaddress": "Test Label"}, "transactions": {}}';

    test('deriveKeyV2 derives identical keys for same mnemonic and salt', () async {
      final salt = List<int>.generate(16, (i) => i);
      final key1 = await BackupEncryptionService.deriveKeyV2(
        mnemonic: mnemonic,
        salt: salt,
      );
      final key2 = await BackupEncryptionService.deriveKeyV2(
        mnemonic: '  $mnemonic  ',
        salt: salt,
      );
      final key3 = await BackupEncryptionService.deriveKeyV2(
        mnemonic: mnemonic.replaceAll(RegExp(r'\s+'), '   '),
        salt: salt,
      );

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      final bytes3 = await key3.extractBytes();

      expect(bytes1, equals(bytes2));
      expect(bytes1, equals(bytes3));
      expect(bytes1.length, equals(32));
    });

    test('encrypt and decrypt round-trip correctly with V2 format', () async {
      final encrypted = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(plainText)));

      // Inspect envelope structure
      final envelopeJson = utf8.decode(base64Decode(encrypted));
      final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;

      expect(envelope['version'], equals(2));
      expect(envelope['algorithm'], equals('AES-256-GCM'));
      expect(envelope['salt'], isNotNull);
      expect(envelope['nonce'], isNotNull);
      expect(envelope['ciphertext'], isNotNull);
      expect(envelope['mac'], isNotNull);

      final decrypted = await BackupEncryptionService.decrypt(
        encryptedCombinedBase64: encrypted,
        mnemonic: mnemonic,
      );

      expect(decrypted, equals(plainText));
    });

    test('encrypt generates unique nonce and salt for every call', () async {
      final enc1 = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );
      final enc2 = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      expect(enc1, isNot(equals(enc2)));

      final env1 = jsonDecode(utf8.decode(base64Decode(enc1))) as Map<String, dynamic>;
      final env2 = jsonDecode(utf8.decode(base64Decode(enc2))) as Map<String, dynamic>;

      expect(env1['nonce'], isNot(equals(env2['nonce'])));
      expect(env1['salt'], isNot(equals(env2['salt'])));
    });

    test('decrypt fails closed on tampered ciphertext (bit-flipping attack)', () async {
      final encrypted = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      final envelope = jsonDecode(utf8.decode(base64Decode(encrypted))) as Map<String, dynamic>;
      final ciphertextBytes = base64Decode(envelope['ciphertext'] as String);

      // Flip a single bit in the ciphertext
      ciphertextBytes[0] ^= 0x01;
      envelope['ciphertext'] = base64Encode(ciphertextBytes);

      final tamperedPayload = base64Encode(utf8.encode(jsonEncode(envelope)));

      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: tamperedPayload,
          mnemonic: mnemonic,
        ),
        throwsFormatException,
      );
    });

    test('decrypt fails closed on tampered MAC tag', () async {
      final encrypted = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      final envelope = jsonDecode(utf8.decode(base64Decode(encrypted))) as Map<String, dynamic>;
      final macBytes = base64Decode(envelope['mac'] as String);

      // Tamper with authentication tag
      macBytes[macBytes.length - 1] ^= 0xFF;
      envelope['mac'] = base64Encode(macBytes);

      final tamperedPayload = base64Encode(utf8.encode(jsonEncode(envelope)));

      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: tamperedPayload,
          mnemonic: mnemonic,
        ),
        throwsFormatException,
      );
    });

    test('decrypt fails closed on incorrect mnemonic', () async {
      final encrypted = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      const wrongMnemonic =
          'wrong mnemonic word list here dynamic dynamic dynamic dynamic dynamic dynamic dynamic';

      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: encrypted,
          mnemonic: wrongMnemonic,
        ),
        throwsFormatException,
      );
    });

    test('decrypt throws on malformed JSON or unsupported version', () async {
      final encrypted = await BackupEncryptionService.encrypt(
        plainText: plainText,
        mnemonic: mnemonic,
      );

      final envelope = jsonDecode(utf8.decode(base64Decode(encrypted))) as Map<String, dynamic>;
      envelope['version'] = 99; // Unsupported future version
      final unsupportedPayload = base64Encode(utf8.encode(jsonEncode(envelope)));

      expect(
        () => BackupEncryptionService.decrypt(
          encryptedCombinedBase64: unsupportedPayload,
          mnemonic: mnemonic,
        ),
        throwsFormatException,
      );

      // Truncated payload
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
        throwsA(isA<FormatException>()),
      );
    });

    test('decrypt successfully imports legacy V1 (AES-CBC) backup', () async {
      // Create a legacy V1 payload: [16-byte IV || AES-CBC ciphertext]
      final normalizedMnemonic = BackupEncryptionService.normalizeMnemonic(mnemonic);
      final keyDigest = crypto.sha256.convert(utf8.encode(normalizedMnemonic));
      final legacyKey = enc.Key(Uint8List.fromList(keyDigest.bytes));
      final legacyIv = enc.IV.fromLength(16);
      final legacyEncrypter = enc.Encrypter(enc.AES(legacyKey, mode: enc.AESMode.cbc));
      final legacyEncrypted = legacyEncrypter.encrypt(plainText, iv: legacyIv);

      final legacyCombinedBytes = Uint8List.fromList([
        ...legacyIv.bytes,
        ...legacyEncrypted.bytes,
      ]);
      final legacyPayload = base64Encode(legacyCombinedBytes);

      final decrypted = await BackupEncryptionService.decrypt(
        encryptedCombinedBase64: legacyPayload,
        mnemonic: mnemonic,
      );

      expect(decrypted, equals(plainText));
    });
  });
}
