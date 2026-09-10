import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:root_wallet/core/security/secure_storage.dart';

/// Hardened PIN management and verification service.
///
/// Features:
/// - Slow key derivation using Argon2id (16MB memory, 3 iterations, 1 parallelism).
/// - Versioned verifier envelope: `$argon2id$v=1$m=16384,t=3,p=1$<salt>$<hash>`
/// - Constant-time comparison to prevent timing side-channels.
/// - Transparent on-the-fly migration from legacy single-round SHA-256 verifiers.
/// - Persistent local brute-force resistance with exponential delay ladder.
/// - Equal security protection for both primary and decoy PINs.
class PinLockService {
  PinLockService(this._secureStorage);

  static const _pinHashKey = 'security.pin_hash';
  static const _pinSaltKey = 'security.pin_salt';
  static const _decoyPinHashKey = 'security.decoy_pin_hash';
  static const _decoyPinSaltKey = 'security.decoy_pin_salt';

  static const _failedAttemptsKey = 'security.failed_attempts';
  static const _cooldownEndsAtKey = 'security.cooldown_ends_at_ms';

  final SecureStorage _secureStorage;

  static final Argon2id _argon2id = Argon2id(
    parallelism: 1,
    memory: 16 * 1024, // 16 MB
    iterations: 3,
    hashLength: 32,
  );

  /// Clears primary PIN and salt.
  Future<void> clearPin() {
    return Future.wait([
      _secureStorage.delete(key: _pinHashKey),
      _secureStorage.delete(key: _pinSaltKey),
    ]);
  }

  /// Checks whether a primary PIN is configured.
  Future<bool> hasPin() async {
    final hash = await _secureStorage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets a new primary PIN using Argon2id slow KDF.
  Future<void> setPin(String pin) async {
    final verifier = await _generateArgon2Verifier(pin);
    await _secureStorage.write(key: _pinHashKey, value: verifier);
    // Remove legacy salt key if present
    await _secureStorage.delete(key: _pinSaltKey);
  }

  /// Clears decoy PIN and salt.
  Future<void> clearDecoyPin() {
    return Future.wait([
      _secureStorage.delete(key: _decoyPinHashKey),
      _secureStorage.delete(key: _decoyPinSaltKey),
    ]);
  }

  /// Checks whether a decoy PIN is configured.
  Future<bool> hasDecoyPin() async {
    final hash = await _secureStorage.read(key: _decoyPinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets a new decoy PIN using Argon2id slow KDF.
  Future<void> setDecoyPin(String pin) async {
    final verifier = await _generateArgon2Verifier(pin);
    await _secureStorage.write(key: _decoyPinHashKey, value: verifier);
    // Remove legacy decoy salt key if present
    await _secureStorage.delete(key: _decoyPinSaltKey);
  }

  /// Verifies [pin] against the stored primary PIN.
  ///
  /// Migrates legacy SHA-256 verifiers transparently to Argon2id on success.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }

    final isMatch = await _verifyAgainstStored(
      pin: pin,
      storedHash: storedHash,
      legacySaltKey: _pinSaltKey,
      onMigrate: () => setPin(pin),
    );

    return isMatch;
  }

  /// Verifies [pin] against the stored decoy PIN.
  ///
  /// Migrates legacy SHA-256 verifiers transparently to Argon2id on success.
  Future<bool> verifyDecoyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _decoyPinHashKey);
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }

    final isMatch = await _verifyAgainstStored(
      pin: pin,
      storedHash: storedHash,
      legacySaltKey: _decoyPinSaltKey,
      onMigrate: () => setDecoyPin(pin),
    );

    return isMatch;
  }

  // --- Local Brute-Force Delay Ladder ---

  /// Returns the current number of consecutive failed attempts.
  Future<int> getFailedAttempts() async {
    final raw = await _secureStorage.read(key: _failedAttemptsKey);
    return raw != null ? (int.tryParse(raw) ?? 0) : 0;
  }

  /// Returns remaining seconds of active cooldown, or 0 if not in cooldown.
  Future<int> getRemainingCooldownSeconds() async {
    final raw = await _secureStorage.read(key: _cooldownEndsAtKey);
    if (raw == null) return 0;
    final endsAtMs = int.tryParse(raw);
    if (endsAtMs == null) return 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = endsAtMs - nowMs;
    if (remainingMs <= 0) {
      return 0;
    }
    return (remainingMs / 1000).ceil();
  }

  /// Increments failed attempts and applies progressive delay ladder.
  ///
  /// Ladder:
  /// - 1-4 failures: 0s
  /// - 5 failures: 30s
  /// - 6 failures: 60s (1 min)
  /// - 7 failures: 300s (5 min)
  /// - 8 failures: 900s (15 min)
  /// - 9 failures: 1800s (30 min)
  /// - 10+ failures: 3600s (1 hr)
  Future<int> recordFailedAttempt() async {
    final current = await getFailedAttempts();
    final next = current + 1;
    await _secureStorage.write(key: _failedAttemptsKey, value: next.toString());

    final delaySeconds = delayForAttempts(next);
    if (delaySeconds > 0) {
      final endsAt = DateTime.now().millisecondsSinceEpoch + (delaySeconds * 1000);
      await _secureStorage.write(key: _cooldownEndsAtKey, value: endsAt.toString());
    }

    return next;
  }

  /// Calculates cooldown delay seconds for a given number of failed attempts.
  int delayForAttempts(int attempts) {
    if (attempts < 5) return 0;
    return switch (attempts) {
      5 => 30,
      6 => 60,
      7 => 300,
      8 => 900,
      9 => 1800,
      _ => 3600,
    };
  }

  /// Clears failed attempts and resets cooldown.
  Future<void> resetLockout() {
    return Future.wait([
      _secureStorage.delete(key: _failedAttemptsKey),
      _secureStorage.delete(key: _cooldownEndsAtKey),
    ]);
  }

  // --- Internal Cryptographic Primitives ---

  Future<bool> _verifyAgainstStored({
    required String pin,
    required String storedHash,
    required String legacySaltKey,
    required Future<void> Function() onMigrate,
  }) async {
    if (storedHash.startsWith(r'$argon2id$v=1$')) {
      return _verifyArgon2(pin, storedHash);
    }

    // Legacy SHA-256 verifier fallback
    final legacySalt = await _secureStorage.read(key: legacySaltKey);
    if (legacySalt == null) {
      return false;
    }

    final isLegacyMatch = _verifyLegacySha256(pin, legacySalt, storedHash);
    if (isLegacyMatch) {
      // Migrate transparently to Argon2id
      await onMigrate();
      return true;
    }

    return false;
  }

  Future<String> _generateArgon2Verifier(String pin) async {
    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rand.nextInt(256));

    final derivedKey = await _argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: saltBytes,
    );
    final hashBytes = await derivedKey.extractBytes();

    final saltBase64 = base64UrlEncode(saltBytes);
    final hashBase64 = base64UrlEncode(hashBytes);

    return r'$argon2id$v=1$m=16384,t=3,p=1$' '$saltBase64\$$hashBase64';
  }

  Future<bool> _verifyArgon2(String pin, String verifier) async {
    try {
      final parts = verifier.split(r'$');
      // Format: ['', 'argon2id', 'v=1', 'm=16384,t=3,p=1', salt, hash]
      if (parts.length != 6 || parts[1] != 'argon2id' || parts[2] != 'v=1') {
        return false;
      }

      final saltBytes = base64Url.decode(parts[4]);
      final expectedHashBytes = base64Url.decode(parts[5]);

      final derivedKey = await _argon2id.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)),
        nonce: saltBytes,
      );
      final actualHashBytes = await derivedKey.extractBytes();

      return _constantTimeEquals(actualHashBytes, expectedHashBytes);
    } catch (_) {
      return false;
    }
  }

  bool _verifyLegacySha256(String pin, String salt, String storedHash) {
    final bytes = utf8.encode('$salt::$pin');
    final actualHash = crypto.sha256.convert(bytes).toString();
    return _constantTimeEquals(
      utf8.encode(actualHash),
      utf8.encode(storedHash),
    );
  }

  /// Constant-time byte equality check to prevent timing attacks.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
