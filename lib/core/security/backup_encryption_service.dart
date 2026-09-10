import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Authenticated encryption service for wallet metadata backups.
///
/// Features:
/// - Primary format (V2): AES-256-GCM with authenticated tags (AEAD).
/// - Key derivation: HKDF-SHA256 with domain separation and per-backup random salt.
/// - Cryptographically secure unique nonces for every encryption.
/// - Tamper and bit-flip detection (fails closed upon authentication error).
/// - Backward-compatible fallback for legacy unauthenticated AES-CBC payloads (V1).
class BackupEncryptionService {
  BackupEncryptionService._();

  static const int currentVersion = 2;
  static const String currentAlgorithm = 'AES-256-GCM';
  static const String _domainSeparationInfo = 'RootWallet-BackupEncryption-v2';

  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  /// Derives a 32-byte (256-bit) encryption key from the BIP39 mnemonic using HKDF-SHA256.
  static Future<SecretKey> deriveKeyV2({
    required String mnemonic,
    required List<int> salt,
  }) async {
    final normalized = normalizeMnemonic(mnemonic);
    final secretKey = SecretKey(utf8.encode(normalized));
    return _hkdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
      info: utf8.encode(_domainSeparationInfo),
    );
  }

  /// Normalizes mnemonic phrase whitespace.
  static String normalizeMnemonic(String mnemonic) {
    return mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Encrypts [plainText] using AES-256-GCM with a key derived from [mnemonic].
  ///
  /// Returns a Base64-encoded JSON envelope containing:
  /// `version`, `algorithm`, `salt`, `nonce`, `ciphertext`, `mac`, `createdAt`.
  static Future<String> encrypt({
    required String plainText,
    required String mnemonic,
  }) async {
    final normalized = normalizeMnemonic(mnemonic);
    if (normalized.isEmpty) {
      throw ArgumentError('Mnemonic cannot be empty.');
    }

    final rand = Random.secure();
    final salt = List<int>.generate(16, (_) => rand.nextInt(256));
    final key = await deriveKeyV2(mnemonic: normalized, salt: salt);

    final plainTextBytes = utf8.encode(plainText);
    final secretBox = await _aesGcm.encrypt(
      plainTextBytes,
      secretKey: key,
    );

    final payload = <String, Object?>{
      'version': currentVersion,
      'algorithm': currentAlgorithm,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    final jsonString = jsonEncode(payload);
    return base64Encode(utf8.encode(jsonString));
  }

  /// Decrypts [encryptedCombinedBase64] using either V2 (AES-256-GCM) or legacy V1 (AES-CBC).
  ///
  /// Fails closed if the payload has been tampered with or if the mnemonic is incorrect.
  static Future<String> decrypt({
    required String encryptedCombinedBase64,
    required String mnemonic,
  }) async {
    final trimmed = encryptedCombinedBase64.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty backup payload.');
    }

    final normalized = normalizeMnemonic(mnemonic);
    if (normalized.isEmpty) {
      throw ArgumentError('Mnemonic cannot be empty.');
    }

    Uint8List rawBytes;
    try {
      rawBytes = base64Decode(trimmed);
    } catch (e) {
      throw FormatException('Invalid Base64 payload: $e');
    }

    // Check if the payload is a V2 JSON envelope (Base64-encoded UTF-8 JSON)
    try {
      final decodedJsonString = utf8.decode(rawBytes);
      final decoded = jsonDecode(decodedJsonString);
      if (decoded is Map<String, dynamic> && decoded.containsKey('version')) {
        return await _decryptV2(decoded, normalized);
      }
    } catch (_) {
      // If not valid UTF-8 JSON, fall through to legacy V1 format check.
    }

    // Fallback to legacy V1 unauthenticated AES-CBC
    return _decryptLegacyV1(rawBytes, normalized);
  }

  /// Decrypts a V2 authenticated payload envelope.
  static Future<String> _decryptV2(
    Map<String, dynamic> envelope,
    String normalizedMnemonic,
  ) async {
    final version = envelope['version'] as int?;
    if (version == null) {
      throw const FormatException('Missing backup version.');
    }
    if (version != currentVersion) {
      throw FormatException('Unsupported backup version: $version');
    }

    final algorithm = envelope['algorithm'] as String?;
    if (algorithm != currentAlgorithm) {
      throw FormatException('Unsupported encryption algorithm: $algorithm');
    }

    final saltBase64 = envelope['salt'] as String?;
    final nonceBase64 = envelope['nonce'] as String?;
    final ciphertextBase64 = envelope['ciphertext'] as String?;
    final macBase64 = envelope['mac'] as String?;

    if (saltBase64 == null ||
        nonceBase64 == null ||
        ciphertextBase64 == null ||
        macBase64 == null) {
      throw const FormatException('Malformed V2 backup envelope: missing fields.');
    }

    final salt = base64Decode(saltBase64);
    final nonce = base64Decode(nonceBase64);
    final ciphertext = base64Decode(ciphertextBase64);
    final macBytes = base64Decode(macBase64);

    if (salt.length < 16) {
      throw const FormatException('Invalid salt length in backup payload.');
    }
    if (nonce.length != 12) {
      throw const FormatException('Invalid nonce length in backup payload.');
    }
    if (macBytes.length != 16) {
      throw const FormatException('Invalid authentication tag length.');
    }

    final key = await deriveKeyV2(mnemonic: normalizedMnemonic, salt: salt);
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    try {
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: key,
      );
      return utf8.decode(decryptedBytes);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Backup authentication failed: incorrect recovery phrase or tampered data.',
      );
    } catch (e) {
      throw FormatException('Backup decryption failed: $e');
    }
  }

  /// Decrypts legacy V1 unauthenticated AES-CBC payload.
  ///
  /// Payload format: `[16-byte IV || AES-CBC ciphertext]`
  static String _decryptLegacyV1(
    Uint8List rawBytes,
    String normalizedMnemonic,
  ) {
    if (rawBytes.length < 16) {
      throw const FormatException('Invalid legacy backup payload (too short).');
    }

    final keyDigest = legacy_crypto.sha256.convert(
      utf8.encode(normalizedMnemonic),
    );
    final key = enc.Key(Uint8List.fromList(keyDigest.bytes));

    final ivBytes = rawBytes.sublist(0, 16);
    final encryptedBytes = rawBytes.sublist(16);

    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    try {
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );
      return utf8.decode(decrypted);
    } catch (e) {
      throw FormatException(
        'Legacy backup decryption failed: incorrect recovery phrase or corrupted payload ($e).',
      );
    }
  }

  /// Legacy helper preserved for unit test verification of key derivation equality.
  static enc.Key deriveKeyLegacy(String mnemonic) {
    final bytes = utf8.encode(normalizeMnemonic(mnemonic));
    final digest = legacy_crypto.sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }
}
