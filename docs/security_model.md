# Root Wallet Security Model & Threat Architecture

Root Wallet is built on the principle: **"Own Bitcoin from the root."**
This document outlines our security architecture, cryptographic safeguards, custody boundaries, and threat mitigation strategies in plain, accessible language for users, developers, and auditors.

---

## 1. Core Principles

- **100% Self-Custodial:** Root Wallet never holds user funds, private keys, or seed phrases on remote servers. Keys are generated on-device and stay on-device.
- **Zero Telemetry / Zero Tracking:** No analytics packages, tracking SDKs, device fingerprinting, or user accounts.
- **Bitcoin-Only Focus:** Minimizes attack surface by eliminating altcoin dependencies, smart contract vulnerabilities, swap counterparty risks, and cross-chain bridge exploits.
- **Testnet-First Hardening:** Mainnet execution is strictly locked behind deliberate compile-time safety guards until all security audits and automated test coverage thresholds are met.

---

## 2. Key Management & Local Storage Architecture

### Hardware-Backed Secure Storage
All sensitive secrets (BIP-39 mnemonic phrase, decoy wallet mnemonic, PIN verifiers, and script type configuration) are stored using platform-native hardware security modules:
- **iOS:** Apple Keychain (`kSecAccessControl` with hardware encryption).
- **Android:** Android KeyStore (AES-GCM encrypted SharedPreferences with hardware-backed master key).

Secrets are never written to unencrypted SQLite tables, disk caches, or log files.

### Mnemonic Lifecycle & Memory Protection
- **Ephemeral Exposure:** When creating a wallet, the 12-word mnemonic phrase is held in memory only until the user completes the backup verification challenge.
- **Immediate State Purge:** Once verified, the recovery phrase is strictly cleared (`null`) from Riverpod state (`OnboardingState.recoveryPhrase = null`).
- **On-Demand Loading:** For transaction signing, BDK loads the mnemonic directly from secure storage in an isolated asynchronous scope, signs the PSBT in Rust memory, and clears the reference.
- **Diagnostics & Snapshot Isolation:** Wallet snapshots and JSON diagnostics exports strictly filter out all secret material.

### PIN Protection with Argon2id
- **Slow Memory-Hard KDF:** PIN verifiers are derived using the Argon2id key derivation function (`memory: 16 MB`, `iterations: 3`, `parallelism: 1`, `hashLength: 32 bytes`).
- **Format:** Serialized as standard PHC envelopes (`$argon2id$v=1$m=16384,t=3,p=1$<salt>$<hash>`).
- **Brute-Force Resistance:** A dedicated brute-force attacker testing 1,000,000 PIN combinations would require tens of gigabytes of RAM and substantial compute time per attack.
- **Persistent Progressive Delay Ladder:** Failed PIN attempts trigger exponential delays (from 2 seconds up to 300 seconds). The lockout countdown and failure counters are persisted in secure storage and cannot be bypassed by restarting the app.
- **Constant-Time Verification:** Verifiers are compared using byte-by-byte constant-time comparison to eliminate timing side-channel attacks.

### Encrypted Backup V2 (AES-256-GCM)
- **Authenticated Encryption:** Backups use AES-256-GCM with a 128-bit authentication tag (`RootBackupV2`).
- **Tamper Detection:** Any modification to the ciphertext, salt, or IV produces an immediate authentication failure rather than corrupt plaintext.
- **Key Derivation:** Encryption keys are derived using HKDF-SHA256 with a unique 32-byte cryptographically secure random salt for every export.
- **Legacy Compatibility:** Seamlessly reads and decrypts legacy AES-CBC V1 backups and re-encrypts them as authenticated V2 backups upon next save.

---

## 3. Threat Model & Mitigations

| Threat | Attack Description | Root Wallet Mitigation |
|---|---|---|
| **Coercion / Physical Search** | An attacker physically forces the user to unlock the device and open Root Wallet. | **Duress Decoy Wallet:** A secondary PIN unlocks a decoy wallet with zero knowledge of or linkage to the primary wallet. Primary data remains completely hidden. |
| **Residual Data on Reset** | An attacker inspects flash storage after a wallet reset to recover old databases. | **Thorough Wipe:** Resetting or restoring a wallet deletes both primary and decoy mnemonic keys and completely purges all primary, decoy, WAL, and SHM SQLite files across the entire storage directory. |
| **Multitasking Card Switcher** | The OS takes a background screenshot thumbnail when the user switches apps. | **App Privacy Overlay:** On iOS, `AppDelegate` overlays a solid dark privacy view upon `applicationWillResignActive`. On Android, `FLAG_SECURE` prevents OS screen capture. |
| **Clipboard Snooping** | Malicious third-party apps or keyboards read copied seed words. | **Auto-Clearing Clipboard:** Copying recovery phrases requires explicit confirmation through a caution modal and triggers automatic clipboard erasure after 60 seconds. |
| **Wrong Network Transmission** | Sending mainnet funds to a testnet address or vice versa. | **Strict Address & Network Guards:** BDK's address parser strictly validates Bech32/Bech32m checksums and enforces network boundaries. `AppConstants.isMainnetAllowed` blocks mainnet execution during testnet testing. |
| **Esplora Backend Censorship** | A single public backend node goes down or fails to broadcast. | **Automatic Node Failover:** Configured with multiple fallback Esplora endpoints and support for custom self-hosted nodes. |
