# Root Wallet Security Audit Report

**Date:** 2026-09-10  
**Repository:** [root-wallet](https://github.com/j-kon/root_wallet)  
**Target Commit:** `673de69` (Branch: `feature/security-hardening-mainnet-readiness`)  
**Scope:** Architecture, Cryptography, Key Storage, Lifecycle, Network Separation, Platform Privacy, Diagnostics, and CI/CD.  
**Auditor:** Antigravity Autonomous Security Agent  

---

## Executive Summary

This security audit was conducted as the mandatory pre-requisite for the **Security Hardening + Mainnet Readiness Foundation** milestone of Root Wallet. The audit traced the lifecycle of all sensitive key material, PIN storage, backup encryption, network communications, UI lifecycle events, and diagnostics data across the entire Flutter codebase and native integration layers.

The audit identified **14 distinct security findings**:
- **3 Critical Severity**
- **4 High Severity**
- **4 Medium Severity**
- **3 Low / Informational Severity**

All findings are documented below with root causes, technical impact, recommended remediations, and tracking status.

---

## Audit Findings Matrix

| ID | Title | Severity | Component / File | Status |
|---|---|---|---|---|
| **SEC-01** | Unauthenticated AES-CBC Backup Encryption & Trivial KDF | **Critical** | `lib/core/security/backup_encryption_service.dart` | Open |
| **SEC-02** | Low-Entropy Salted SHA-256 PIN Verifier Lacking Slow KDF | **Critical** | `lib/core/security/pin_lock_service.dart` | Open |
| **SEC-03** | Mnemonic Stored in Riverpod Global Application State | **Critical** | `lib/features/wallet/domain/entities/wallet_identity.dart` | Open |
| **SEC-04** | Decoy Wallet SQLite Database Leaked on Device Storage on Reset | **High** | `lib/features/wallet/data/services/bdk_wallet_service.dart` | Open |
| **SEC-05** | iOS Multitasking App-Switcher Snapshot Privacy Leak | **High** | `ios/Runner/AppDelegate.swift` | Open |
| **SEC-06** | Ephemeral In-Memory PIN Lockout Counter Bypassed via App Restart | **High** | `lib/features/settings/presentation/providers/security_providers.dart` | Open |
| **SEC-07** | Clipboard Indefinite Retention of Plaintext Recovery Words | **High** | `lib/features/wallet/presentation/pages/backup_seed_page.dart` | Open |
| **SEC-08** | Non-Constant-Time PIN Equality Comparison | **Medium** | `lib/core/security/pin_lock_service.dart` | Open |
| **SEC-09** | Lack of Network Database Namespace Isolation | **Medium** | `lib/features/wallet/data/services/bdk_wallet_service.dart` | Open |
| **SEC-10** | Regex-Only Address Validation Lacks Checksum Verification | **Medium** | `lib/features/send/presentation/models/bitcoin_uri_parser.dart` | Open |
| **SEC-11** | Missing iOS Keychain Accessibility Parameter in Secure Storage | **Medium** | `lib/core/security/secure_storage.dart` | Open |
| **SEC-12** | Verbose Debug Logging Exposing Addresses and Internal State | **Low** | `lib/features/wallet/data/services/bdk_wallet_service.dart` | Open |
| **SEC-13** | Absolute Filesystem Path Disclosure in Diagnostics Export | **Low** | `lib/features/wallet/domain/entities/wallet_diagnostics.dart` | Open |
| **SEC-14** | Mutable Action References in GitHub Actions CI Pipeline | **Informational** | `.github/workflows/flutter.yml` | Open |

---

## Detailed Findings

### SEC-01: Unauthenticated AES-CBC Backup Encryption & Trivial KDF
- **Severity:** Critical
- **File:** `lib/core/security/backup_encryption_service.dart`
- **Problem:**
  `BackupEncryptionService` encrypts metadata backups using AES in Cipher Block Chaining (CBC) mode with PKCS7 padding. Key derivation is performed using single-round unkeyed `sha256(mnemonic)` without a salt, domain separation, or key stretching algorithm.
- **Impact:**
  1. **Lack of Authenticity & Tamper Resistance:** AES-CBC does not provide cryptographic integrity or authenticity (AEAD). Ciphertext blocks can be manipulated, reordered, or bit-flipped.
  2. **Padding Oracle Vulnerability:** In distributed or cloud-stored backup scenarios, malformed padding exceptions can leak plaintext bytes.
  3. **Weak Key Derivation:** Direct single-round SHA-256 derivation lacks domain separation, making the key identical to any other SHA-256 usage of the mnemonic.
- **Recommended Fix:**
  - Upgrade to authenticated encryption: **AES-256-GCM** (or ChaCha20-Poly1305).
  - Use domain-separated HKDF-SHA256 with an explicit application salt (`RootWallet-BackupEncryption-v2`).
  - Introduce a versioned container envelope (`RootBackupV2`) containing explicit `version`, `cipher`, `nonce`, `ciphertext`, and authentication `mac` tag.
  - Fail closed on any tampering or authentication tag mismatch.
  - Provide a backward-compatible import path for legacy AES-CBC payloads, re-encrypting them as V2 upon import.
- **Status:** Open

---

### SEC-02: Low-Entropy Salted SHA-256 PIN Verifier Lacking Slow KDF
- **Severity:** Critical
- **File:** `lib/core/security/pin_lock_service.dart`
- **Problem:**
  The PIN verifier computes a single round of SHA-256 over `$salt::$pin`. For a 4-to-6 digit numeric PIN (10,000 to 1,000,000 combinations), SHA-256 can be computed millions of times per second per thread on consumer hardware.
- **Impact:**
  If an attacker obtains physical access to a jailbroken/rooted device or extracts the secure storage database, the entire 6-digit PIN keyspace can be brute-forced in under 5 milliseconds.
- **Recommended Fix:**
  - Replace single-round SHA-256 with a memory-hard, deliberately slow key derivation function: **Argon2id** (configured with 16MB memory, 3 iterations, 1 parallelism, 32-byte output) or PBKDF2-HMAC-SHA256 (100,000 iterations).
  - Store verifiers in a structured, versioned envelope: `$argon2id$v=1$m=16384,t=3,p=1$<salt>$<hash>`.
  - Provide transparent migration from legacy SHA-256 verifiers on the next successful authentication.
- **Status:** Open

---

### SEC-03: Mnemonic Stored in Riverpod Global Application State
- **Severity:** Critical
- **File:** `lib/features/wallet/domain/entities/wallet_identity.dart`, `lib/features/onboarding/presentation/providers/onboarding_providers.dart`
- **Problem:**
  `WalletIdentity` contains `final String? recoveryPhrase;`. This causes the full BIP-39 plaintext seed phrase to be passed into ordinary Riverpod state notifiers, route arguments, and view entities, where it remains resident in memory throughout the lifetime of the application.
- **Impact:**
  Any memory inspection, heap dump, or accidental serialization of `WalletIdentity` will expose the user's master root key.
- **Recommended Fix:**
  - Remove `recoveryPhrase` from `WalletIdentity`. `WalletIdentity` must represent public, non-sensitive metadata only (`id`, `fingerprint`, `network`).
  - Introduce a dedicated, ephemeral `WalletCreationResult` model containing `walletIdentity` and `recoveryPhrase`, used strictly during wallet creation.
  - Invalidate the mnemonic in memory immediately once initial backup confirmation is complete.
- **Status:** Open

---

### SEC-04: Decoy Wallet SQLite Database Leaked on Device Storage on Reset
- **Severity:** High
- **File:** `lib/features/wallet/data/services/bdk_wallet_service.dart`
- **Problem:**
  When a decoy wallet is active, BDK creates SQLite database files with a `decoy_` prefix (e.g. `decoy_root_wallet_testnet_...sqlite`). However, `_deleteWalletDatabase()` only targets files matching `root_wallet_testnet_...sqlite` without the `decoy_` prefix.
- **Impact:**
  When a user executes a "Reset Wallet" or creates a new wallet, the decoy wallet's transactions, addresses, and UTXO database are NOT deleted from device disk storage. Forensics or file-level inspection will reveal that a decoy wallet existed and reveal historical transaction records.
- **Recommended Fix:**
  - Update `_deleteWalletDatabase()` and `resetWallet()` to enumerate and purge all database files matching both primary and decoy prefixes, including SQLite journal, WAL, and SHM companion files.
- **Status:** Open

---

### SEC-05: iOS Multitasking App-Switcher Snapshot Privacy Leak
- **Severity:** High
- **File:** `ios/Runner/AppDelegate.swift`
- **Problem:**
  On Android, `MainActivity.kt` enforces `WindowManager.LayoutParams.FLAG_SECURE` when screen protection is active. On iOS, `AppDelegate.swift` returns `false` on `setProtected` and registers no hooks for `applicationWillResignActive` or `applicationDidBecomeActive`.
- **Impact:**
  When Root Wallet is moved to the background on iOS, the operating system takes a snapshot of the current window to display in the multitasking carousel. If the user was viewing their seed phrase, transaction history, or wallet balance, an unredacted screenshot is written to the unencrypted iOS snapshot cache on disk.
- **Recommended Fix:**
  - Implement window obscuring in `AppDelegate.swift`: overlay a solid brand privacy view over the key window on `applicationWillResignActive` and remove it on `applicationDidBecomeActive`.
- **Status:** Open

---

### SEC-06: Ephemeral In-Memory PIN Lockout Counter Bypassed via App Restart
- **Severity:** High
- **File:** `lib/features/settings/presentation/providers/security_providers.dart`
- **Problem:**
  Failed PIN attempts and lockout cooldowns are tracked in memory within `LockController` (`failedAttempts` in Riverpod state). The cooldown duration is fixed at 15 seconds after 5 attempts, and then resets back to 0.
- **Impact:**
  1. An unauthorized individual in possession of the phone can bypass the 15-second lockout by simply force-closing and reopening the application.
  2. The lack of an exponential delay ladder allows automated or scripted local attacks if the UI can be automated.
- **Recommended Fix:**
  - Persist failed attempt counts and lockout expiration timestamps in `SecureStorage`.
  - Implement a progressive exponential delay ladder: 5 attempts = 30s; 6 = 1m; 7 = 5m; 8 = 15m; 9 = 30m; 10+ = 1h.
  - Do NOT wipe the wallet on failure (the recovery phrase is the recovery mechanism), but enforce persistent hardware-backed delay gating.
- **Status:** Open

---

### SEC-07: Clipboard Indefinite Retention of Plaintext Recovery Words
- **Severity:** High
- **File:** `lib/features/wallet/presentation/pages/backup_seed_page.dart`
- **Problem:**
  When a user taps "Copy recovery phrase" on `backup_seed_page.dart`, the plaintext 12-word phrase is copied to the system pasteboard via `Clipboard.setData()`. There is no automated clipboard clearing scheduled.
- **Impact:**
  The master recovery phrase remains in the system clipboard indefinitely. Third-party applications, background clip managers, or keyboard software can read the clipboard contents without user knowledge.
- **Recommended Fix:**
  - Create a managed `ClipboardService` with an automatic timer (e.g. 60 seconds) that clears the pasteboard after sensitive material is copied.
  - Display prominent warning modals before allowing clipboard copies of the seed phrase.
- **Status:** Open

---

### SEC-08: Non-Constant-Time PIN Equality Comparison
- **Severity:** Medium
- **File:** `lib/core/security/pin_lock_service.dart`
- **Problem:**
  PIN verification checks `hash == _hash(pin, salt)`. In Dart, the `String.==` operator compares character-by-character and early-exits upon the first differing character.
- **Impact:**
  Timing differences can theoretically allow side-channel inference of matching hash prefixes over repeated measurements.
- **Recommended Fix:**
  - Use constant-time byte comparison (e.g., XOR accumulator over all bytes or `package:cryptography` constant-time equals).
- **Status:** Open

---

### SEC-09: Lack of Network Database Namespace Isolation
- **Severity:** Medium
- **File:** `lib/features/wallet/data/services/bdk_wallet_service.dart`
- **Problem:**
  Wallet database paths and cache keys are stored in a flat directory (`root_wallet_${network.name}_...sqlite`). There is no centralized `BitcoinNetworkEnvironment` abstraction to enforce strict filesystem path segregation between testnet, mainnet, and signet.
- **Impact:**
  If mainnet is enabled without strict path namespacing, configuration bugs or testnet/mainnet switching could corrupt or cross-contaminate local wallet state or UTXO caches.
- **Recommended Fix:**
  - Implement `BitcoinNetworkEnvironment` with isolated directory namespaces (`$walletDir/testnet/`, `$walletDir/mainnet/`, `$walletDir/signet/`).
  - Keep testnet as the sole default and lock mainnet behind an explicit build configuration flag.
- **Status:** Open

---

### SEC-10: Regex-Only Address Validation Lacks Checksum Verification
- **Severity:** Medium
- **File:** `lib/features/send/presentation/models/bitcoin_uri_parser.dart`, `lib/features/send/presentation/models/send_draft.dart`
- **Problem:**
  `BitcoinUriParser` and `SendDraft.hasValidAddress` use basic length and regex prefix checks (`tb1`, `[mn2]`) rather than decoding the Bech32 / Base58Check checksum.
- **Impact:**
  A user typing an address with a typo will pass UI validation and only encounter an error deep in the PSBT builder phase.
- **Recommended Fix:**
  - Use BDK `Address` parsing or dedicated Bech32/Base58Check validation to verify cryptographic checksums before allowing transaction preview.
- **Status:** Open

---

### SEC-11: Missing iOS Keychain Accessibility Parameter in Secure Storage
- **Severity:** Medium
- **File:** `lib/core/security/secure_storage.dart`
- **Problem:**
  `FlutterSecureStorageAdapter` specifies `AndroidOptions(encryptedSharedPreferences: true)` for Android, but does not provide explicit `IOSOptions`.
- **Impact:**
  On iOS, Keychain items default to `kSecAttrAccessibleWhenUnlocked`, which may permit unauthorized access in certain background execution modes, or fail if background syncing is attempted.
- **Recommended Fix:**
  - Explicitly configure `IOSOptions(accessibility: KeychainAccessibility.first_unlock)` to ensure Keychain accessibility is consistent and secure.
- **Status:** Open

---

### SEC-12: Verbose Debug Logging Exposing Addresses and Internal State
- **Severity:** Low
- **File:** `lib/features/wallet/data/services/bdk_wallet_service.dart`, `lib/features/wallet/data/repositories/wallet_repository_impl.dart`, `lib/features/send/presentation/providers/send_providers.dart`
- **Problem:**
  Over 30 instances of `print('DEBUG...')` statements log internal BDK wallet operations, Electrum endpoint attempts, receive addresses, and error traces to the standard output.
- **Impact:**
  On mobile devices, `print()` outputs to Android Logcat and iOS system logs, where unprivileged applications or crash-reporting services could inspect user addresses and connection behaviors.
- **Recommended Fix:**
  - Remove all raw `print()` statements from production code. Wrap diagnostic logs in a structured logger that is disabled in release builds.
- **Status:** Open

---

### SEC-13: Absolute Filesystem Path Disclosure in Diagnostics Export
- **Severity:** Low
- **File:** `lib/features/wallet/domain/entities/wallet_diagnostics.dart`
- **Problem:**
  The "Copy diagnostics" feature serializes `walletDatabasePath` into the exported JSON, exposing internal OS usernames, mount points, and application container UUIDs.
- **Impact:**
  Users sharing diagnostics for debugging or support expose device-identifying filesystem structure.
- **Recommended Fix:**
  - Redact absolute filesystem paths to relative or sanitized paths (e.g. `<app_storage>/testnet/root_wallet.sqlite`).
- **Status:** Open

---

### SEC-14: Mutable Action References in GitHub Actions CI Pipeline
- **Severity:** Informational
- **File:** `.github/workflows/flutter.yml`
- **Problem:**
  The workflow uses mutable branch/tag references: `actions/checkout@v4` and `subosito/flutter-action@v2`.
- **Impact:**
  If an upstream action repository is compromised, malicious code could run during CI builds.
- **Recommended Fix:**
  - Pin actions to immutable 40-character commit SHAs.
  - Introduce automated dependency audit checks.
- **Status:** Open

---

## Conclusion

The Root Wallet codebase possesses a sound self-custodial architecture powered by `bdk_dart`. However, the critical and high-severity findings identified in this audit—specifically the unauthenticated AES-CBC backup encryption, weak single-round PIN hashing, plaintext mnemonic in Riverpod state, and iOS app-switcher privacy exposure—must be resolved before Root Wallet can be considered ready for mainnet release and store distribution.

All remediations planned in Phases 2 through 10 will directly address these findings.
