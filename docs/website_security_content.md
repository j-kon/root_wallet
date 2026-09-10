# Root Wallet: Public Security Overview

*This document outlines the user-facing content for the upcoming official Root Wallet website (`/security`). It provides an honest, technical, and transparent breakdown of our security posture.*

> [!WARNING]
> **ROOT WALLET IS CURRENTLY TESTNET SOFTWARE.**  
> It is not currently recommended for storing real Bitcoin. Mainnet remains disabled.

---

## Headline: Security Without the Noise

True Bitcoin security is not about marketing buzzwords. It is about defense-in-depth, minimal attack surfaces, verifiable cryptography, and user ownership.

> **Our Commitment to Honesty:**  
> Security hardening is an ongoing, continuous process. We do not claim to be "100% unhackable" or "military-grade." Instead, we engineer Root Wallet from first principles, document our threat model openly, and invite public review of every line of code.

---

## 1. Where Your Secrets Live

- **Strict Local Self-Custody:** 12-word recovery phrases, private keys, and master extended keys (`xprv`/`tprv`) are generated directly on your mobile device using OS-grade cryptographically secure pseudorandom number generators (CSPRNG). Recovery phrases and private keys are designed to remain on the device under user control.
- **Platform Secure Storage:** Encrypted seed material is stored using platform-native secure storage mechanisms:
  - **iOS:** Apple Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` flags.
  - **Android:** Android KeyStore using AES encryption.
- **Zero Server Exposure:** Root Wallet has no central servers, no user accounts, and no recovery databases. We cannot freeze your funds, reset your PIN, or view your private keys. Root Wallet communicates with Bitcoin network infrastructure solely for blockchain synchronization and transaction broadcasting.

---

## 2. Cryptographic Engine: Bitcoin Dev Kit (BDK)

All Bitcoin transaction creation, coin selection, script evaluation, and cryptographic signing are delegated to [Bitcoin Dev Kit (BDK)](https://bitcoindevkit.org/).

- **Rust Security:** BDK is written in memory-safe Rust, providing robust protection against buffer overflows, use-after-free bugs, and memory corruption attacks.
- **Native FFI Layer:** Root Wallet communicates with BDK through compiled native C-ABI bindings via `bdk_dart`.
- **Reproducible Dependencies:** Build dependencies are strictly pinned and verified via SHA-256 checksums to guard against upstream supply chain tampering.

---

## 3. Defense-in-Depth Features

### Argon2id Memory-Hard PIN Protection
Unlike basic consumer apps that hash PINs with fast algorithms vulnerable to instant GPU/ASIC cracking, Root Wallet verifies lock PINs using **Argon2id** (`16 MB memory, 3 iterations, 1 lane`).
- **Persistent Lockout Escalation:** Incorrect PIN entries trigger an escalating lockout ladder (2s → 5s → 15s → 60s → 300s) that is stored in platform secure storage and cannot be bypassed by force-quitting the app.
- **Decoy PIN Duress Support:** Entering an optional secondary decoy PIN unlocks an isolated, empty wallet database with zero link to your real funds.

### Authenticated Encrypted Backups (AES-256-GCM)
Exported wallet backups are protected with pure-Dart **AES-256-GCM** using keys derived via HKDF-SHA256 with 32-byte unique salts and 12-byte initialization vectors.
- **Tamper Detection:** The 128-bit authentication tag detects byte corruption or tampering, mitigating padding-oracle attacks.

### Ephemeral Recovery Phrase Lifecycle
- **Zero Retention in Identity Models:** Recovery phrases are not stored in general memory models or persistent application state.
- **State Lifetime Reduction:** Recovery phrases are exposed to application state only during user-initiated backup or reveal flows and references are removed as soon as the flow completes. Note that deterministic memory zeroization is not guaranteed by the Dart runtime.

### Device Privacy & Screen Shielding
- **Multitasking Shielding:** When transitioning to the app switcher on iOS and Android, an opaque branded privacy shield immediately hides sensitive balances and addresses.
- **Screenshot Protection:** Screen-capture blocking is enforced during seed phrase display on supported platforms.
- **Auto-Clearing Clipboard:** Sensitive clipboard copies (such as recovery words) are automatically sanitized from the system clipboard after 60 seconds.

---

## 4. Network Privacy & Blockchain Backend Realities

We believe in complete transparency about what happens over the network:

- **Current Public Infrastructure:** In the current Testnet environment, Root Wallet queries public Blockstream Esplora and Electrum servers for UTXOs and transaction broadcasts.
- **What External Nodes Can See:** External servers observe your device's IP address and the Bitcoin addresses you request.
- **Upcoming Self-Sovereignty:** Our active roadmap includes custom node configuration, local Electrum server endpoints, and native Tor/SOCKS5 proxy support to enhance network privacy.

---

## 5. Security Status & Planned Independent Audits

- **Internal Hardening Complete:** All 14 vulnerability findings from our initial architectural assessment have been systematically remediated (see our internal [Security Audit Report](../SECURITY_AUDIT.md)).
- **Upcoming Milestone:** Prior to mainnet release, Root Wallet will engage an independent third-party cybersecurity firm to conduct a comprehensive cryptographic and code security audit.
- **Open-Source Codebase:** Root Wallet is open-source (dual-licensed under MIT OR Apache-2.0). Pull requests undergo automated static analysis, security tests, and regression suites.

---

## 6. Responsible Disclosure Program

We actively collaborate with independent security researchers. If you discover a potential vulnerability, please report it responsibly:

- 🔒 **Private Vulnerability Reporting:** Please use GitHub Private Vulnerability Reporting when available on the repository.
- 🛡️ **Alternative Private Contact:** If private reporting is temporarily unavailable, contact the project maintainer privately using a verified contact method listed on the repository. See [SECURITY.md](../SECURITY.md) for full details.
- ⏱️ **Coordination:** We aim to acknowledge responsible security reports as soon as reasonably possible and will coordinate remediation and disclosure based on severity.
