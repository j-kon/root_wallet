import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupEncryptionService {
  BackupEncryptionService._();

  /// Derives a 32-byte (256-bit) encryption key from the BIP39 mnemonic using SHA-256.
  static enc.Key deriveKey(String mnemonic) {
    final bytes = utf8.encode(mnemonic.trim().replaceAll(RegExp(r'\s+'), ' '));
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts the [plainText] using AES-CBC with a derived key from [mnemonic].
  /// Returns a combined Base64 string of IV + CipherText to store easily.
  static String encrypt({required String plainText, required String mnemonic}) {
    final key = deriveKey(mnemonic);
    final iv = enc.IV.fromLength(16); // 16 bytes for AES block size
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Combine IV and CipherText bytes so they can be saved/copied together
    final combinedBytes = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return base64Encode(combinedBytes);
  }

  /// Decrypts the [encryptedCombinedBase64] using AES-CBC with a derived key from [mnemonic].
  static String decrypt({
    required String encryptedCombinedBase64,
    required String mnemonic,
  }) {
    final key = deriveKey(mnemonic);
    final combinedBytes = base64Decode(encryptedCombinedBase64.trim());
    if (combinedBytes.length < 16) {
      throw const FormatException('Invalid backup payload (too short)');
    }
    
    final ivBytes = combinedBytes.sublist(0, 16);
    final encryptedBytes = combinedBytes.sublist(16);
    
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(Uint8List.fromList(encryptedBytes)),
      iv: iv,
    );
    
    return utf8.decode(decrypted);
  }
}
