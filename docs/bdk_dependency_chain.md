# BDK Dependency Chain & Cryptographic Verification

This document details the Bitcoin Dev Kit (BDK) dependency supply chain for Root Wallet, including pinning rationale, native library boundaries, cryptographic primitives, and the upgrade pathway to final 1.0.

---

## 1. Supply Chain Architecture

Root Wallet interfaces with the Bitcoin network and handles BIP39/BIP32/BIP84/BIP86 keys through the following layered architecture:

```
┌────────────────────────────────────────────────────────┐
│               Root Wallet UI & Business Logic          │
│                  (Flutter / Dart / Riverpod)           │
└───────────────────────────┬────────────────────────────┘
                            │ Dart FFI Calls
┌───────────────────────────▼────────────────────────────┐
│                       bdk_dart                         │
│       https://github.com/bitcoindevkit/bdk-dart        │
│          Pinned Tag: v1.0.0-rc.2                       │
│    Resolved Commit: 801da8e4acb825ef323b0fcc7e3277348c2 │
└───────────────────────────┬────────────────────────────┘
                            │ UniFFI C-ABI Bridge
┌───────────────────────────▼────────────────────────────┐
│                    bdk-ffi (Rust)                      │
│            C Foreign Function Interface layer          │
└───────────────────────────┬────────────────────────────┘
                            │ Rust static link
┌───────────────────────────▼────────────────────────────┐
│               BDK Core Rust Crates (1.0.0-rc.2)        │
│  - bdk_wallet: Descriptor wallet, coin selection, PSBT │
│  - bdk_chain: Local UTXO & block header tracker        │
│  - bdk_esplora: HTTP Esplora sync client               │
│  - rust-bitcoin: Consensus rules & secp256k1 bindings  │
└────────────────────────────────────────────────────────┘
```

---

## 2. Dependency Pinning Rationale

In `pubspec.yaml`, `bdk_dart` is pinned to a specific git tag:

```yaml
bdk_dart:
  git:
    url: https://github.com/bitcoindevkit/bdk-dart.git
    ref: v1.0.0-rc.2
```

In `pubspec.lock`, the exact resolved commit is verified:
`801da8e4acb825ef323b0fcc7e3277348c20b3ae`.

### Why Pinned to Git Tag & Commit?
1. **Deterministic Reproducibility:** Pinning prevents unintended upstream breaking changes or dependency substitution attacks.
2. **Native Binary Predictability:** `bdk_dart` bundles precompiled native binaries (`bdkFFI.xcframework` and `libbdkFFI.so`). Pinning ensures that every developer and CI build links against identical native binaries with known SHA checksums.
3. **BDK 1.0 Architecture:** `v1.0.0-rc.2` was the first milestone providing the modernized `bdk_wallet` + `bdk_chain` architecture with decoupled database persistence (`Persister`), SQLite support, and transaction extraction.

---

## 3. Native Platform Binaries

### iOS (`ios/Frameworks` / CocoaPods dependency)
- **Framework:** `bdkFFI.xcframework`
- **Architectures:**
  - `ios-arm64`: iPhone / iPad physical devices.
  - `ios-arm64_x86_64-simulator`: Apple Silicon (M1/M2/M3) and Intel Mac iOS Simulators.
- **Linkage:** Automatically linked through Flutter tooling using standard iOS module linking.

### Android (`android/app/src/main/jniLibs`)
- **Shared Objects:** `libbdkFFI.so`
- **Architectures:**
  - `arm64-v8a`: Modern 64-bit ARM devices (99%+ of Android devices).
  - `armeabi-v7a`: Legacy 32-bit ARM devices.
  - `x86_64`: Android Studio x86_64 emulators.

---

## 4. Cryptographic Primitives & Consensus Rust Crates

Underneath `bdk_dart`, the Rust core utilizes the following cryptographic libraries:

| Primitive / Domain | Rust Implementation | Security Characteristics |
|---|---|---|
| **Elliptic Curve Cryptography** | `secp256k1` (C library via `rust-secp256k1`) | Constant-time execution, hardened against side-channel attacks, verified against Bitcoin Core reference tests. |
| **BIP-39 Mnemonic** | `bip39` crate | Generates 128-bit / 256-bit entropy using OS CSPRNG (`getrandom`), validates PBKDF2 HMAC-SHA512 checksums. |
| **BIP-32 / BIP-84 / BIP-86** | `rust-bitcoin` | Hierarchical Deterministic (HD) derivation for Native SegWit (`m/84'/0'/0'`) and Taproot (`m/86'/0'/0'`). |
| **Hashing** | `bitcoin_hashes` | SHA-256, RIPEMD-160, HASH-160, HASH-256, and HMAC implementations verified against NIST vectors. |
| **Transaction Signing** | `bdk_wallet` PSBT engine | BIP-174 Partically Signed Bitcoin Transactions with standard sighash verification. |

---

## 5. Known Differences Upstream (rc.2 vs. Later Releases)

Since `1.0.0-rc.2`, upstream BDK made several iterative refinements in `1.0.0-rc.3`, `1.0.0-rc.4`, and final `1.0`:

1. **Persister Flushing:** `1.0.0-rc.4` tightened atomic transaction commits in SQLite persisters to guard against abrupt OS termination during DB sync. Root Wallet currently mitigates this via explicit SQLite WAL (Write-Ahead Logging) mode and synchronized `_persistWallet()` calls.
2. **Esplora Parallel Request Throttling:** Later rc versions improved HTTP connection reuse in the Esplora client. Root Wallet explicitly bounds request concurrency to 2 (`AppConstants.esploraRequestConcurrency = 2`) with automatic failover between multiple endpoints.
3. **Descriptor Validation:** Minor improvements in miniscript validation for complex descriptor scripts. (Root Wallet exclusively uses standard single-key BIP84 P2WPKH and BIP86 P2TR descriptors, which are fully stable in rc.2).

---

## 6. Migration Checklist for Future BDK Releases

When `bdk_dart` publishes an official stable GA release (e.g. `1.0.0`):

1. [ ] Update `pubspec.yaml` to point to the new release tag or pub.dev hosted package.
2. [ ] Run `flutter pub get` and verify `pubspec.lock` git hash and version.
3. [ ] Run `flutter test test/security/` to confirm mnemonic lifecycle and address validation tests pass.
4. [ ] Verify database schema compatibility: check whether BDK database format required migration. If so, increment `AppConstants.walletDatabaseSchemaVersion`.
5. [ ] Test wallet creation, restore, balance sync, address rotation, and send PSBT flow on testnet.
6. [ ] Rebuild iOS and Android native binaries and verify test device launch without symbol collisions.
