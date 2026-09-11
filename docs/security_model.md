# Root Wallet Security Model & Threat Architecture

Root Wallet is built on the principle: **"Own Bitcoin from the root."**
This document outlines our security architecture, cryptographic safeguards, custody boundaries, and threat mitigation strategies in plain, accessible language for users, developers, and reviewers.

---

## 1. Core Principles

- **Self-Custodial:** Root Wallet does not hold user funds, private keys, or recovery phrases on remote servers. Recovery phrases and private keys are generated on-device and designed to remain on-device.
- **Zero Telemetry / Zero Tracking:** No analytics packages, tracking SDKs, device fingerprinting, or user accounts.
- **Bitcoin-Only Focus:** Minimizes attack surface by eliminating altcoin dependencies, smart contract vulnerabilities, swap counterparty risks, and cross-chain bridge exploits.
- **Testnet-First Hardening:** Mainnet execution is disabled by a compile-time constant and rejected by runtime network checks until security reviews and independent audits are complete.

---

## 2. Key Management & Local Storage Architecture

### Platform Secure Storage
All sensitive secrets (BIP-39 mnemonic phrase, decoy wallet mnemonic, PIN verifiers, and script type configuration) are stored using platform-native secure storage:
- **iOS:** Apple Keychain with secure access attributes.
- **Android:** Android KeyStore (encrypted SharedPreferences with master key).

Secrets are never written to unencrypted SQLite tables, disk caches, or log files.

### Mnemonic Lifecycle & Memory Protection
- **Minimized State Lifetime:** When creating a wallet, the 12-word mnemonic phrase is held in application state only until the user completes the backup verification challenge.
- **State Reference Removal:** Once verified, the recovery phrase is removed from Riverpod state (`OnboardingState.recoveryPhrase = null`). Note that while application references are cleared, deterministic memory zeroization is not guaranteed by the Dart runtime garbage collector.
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
| **Residual Data on Reset** | An attacker inspects storage after a wallet reset to recover old databases. | **Storage Erasure:** Resetting or restoring a wallet deletes primary and decoy keys from secure storage and purges primary, decoy, WAL, and SHM SQLite files from application storage. |
| **Multitasking Card Switcher** | The OS takes a background screenshot thumbnail when the user switches apps. | **App Privacy Overlay:** On iOS, `AppDelegate` overlays a solid dark privacy view upon `applicationWillResignActive`. On Android, `FLAG_SECURE` prevents OS screen capture. |
| **Clipboard Snooping** | Malicious third-party apps or keyboards read copied seed words. | **Auto-Clearing Clipboard:** Copying recovery phrases requires explicit confirmation through a caution modal and triggers automatic clipboard erasure after 60 seconds. |
| **Wrong Network Transmission** | Sending mainnet funds to a testnet address or vice versa. | **Strict Address & Network Guards:** BDK's address parser strictly validates Bech32/Bech32m checksums and enforces network boundaries. `AppConstants.isMainnetAllowed` blocks mainnet execution during testnet testing. |
| **Esplora Backend Censorship** | A single public backend node goes down or fails to broadcast. | **Automatic Node Failover:** Configured with multiple fallback Esplora endpoints and support for custom self-hosted nodes. |
| **Network Surveillance & IP Leaks** | Network observers, ISPs, or node operators correlate Bitcoin addresses and transactions with user IP addresses. | **SOCKS5 Privacy Routing:** Routes Electrum traffic through a user-configured SOCKS5 proxy with remote DNS resolution and strict fail-closed enforcement (no silent clearnet fallback). |

---

## 4. Network Privacy & SOCKS5 Routing Architecture

Root Wallet supports routing Bitcoin backend traffic through a user-configured SOCKS5 proxy (such as a local Tor daemon or Orbot). This architecture is governed by strict privacy-first principles:

### Fail-Closed Guarantee
- When SOCKS5 transport is enabled, all Bitcoin network operations (wallet synchronization, transaction broadcasting, fee estimation, and tip height inspection) MUST route through the proxy.
- If the proxy is unavailable, misconfigured, or offline, operations fail immediately and visibly.
- **Root Wallet NEVER silently falls back to clearnet.** Silent fallbacks defeat user privacy expectations by leaking IP addresses and active descriptors at the moment of failure.

### Remote DNS Resolution (No Local DNS Leaking)
- Electrum connections over SOCKS5 utilize SOCKS5 domain name addressing (`0x03`), passing hostnames directly to the proxy for remote resolution.
- Device OS resolvers never perform local DNS queries for Bitcoin endpoints, preventing DNS snooping by local networks or ISPs.
- Native support for Tor v3 `.onion` hidden service addresses over TCP and TLS.

### Upstream Capability Gating (Electrum vs. Esplora)
- BDK's Electrum client (`electrum-client 0.25.0`) natively supports SOCKS5 proxying via Rust TCP/TLS stream wrapping.
- BDK's Esplora client (`bdk_esplora 0.22.2` / `esplora-client 0.12.3`) relies on `minreq 2.14.1`, which only supports HTTP CONNECT proxies and errors on SOCKS5.
- Therefore, when SOCKS5 mode is active, Root Wallet automatically bypasses Esplora completely and routes all synchronization, broadcasting, fee queries, and chain height calls exclusively through Electrum over SOCKS5.

### Custom Backend Isolation (No Public Fallback)
- When a custom Electrum server is configured, Root Wallet queries only that server.
- If the custom server is unreachable or offline, wallet operations fail closed immediately.
- The wallet **NEVER** silently falls back to public Electrum nodes when a custom server is defined, preserving single-backend isolation and avoiding metadata exposure.

### Transport Mode Fail-Closed Parsing
- Persisted transport configuration uses strict validation (`NetworkTransportMode.parsePersisted`).
- If stored configuration is corrupted or invalid (`"socks"`, `"sock5"`, `"tor"`, `""`, `"unknown"`), the parser throws `NetworkConfigurationException` and wallet initialization fails closed.
- Only an absent key (`null`) on a genuine fresh install defaults to `direct` mode.

### Destination Target vs Proxy Host Separation
- SOCKS5 proxy host must be a local or reachable network endpoint (e.g., `127.0.0.1`, `localhost`, or LAN IP).
- Tor `.onion` addresses are strictly destination targets, not proxy listeners. Entering `.onion` as a proxy host is rejected with actionable error guidance.
- Onion targets are configured in the Custom Electrum Server field and validated against the Tor v3 specification (exactly 56 base32 characters).

### Transport Privacy & Proxy Limits
- When the configured SOCKS5 proxy is functioning, the selected Electrum backend does not receive the device's direct IP address.
- The SOCKS proxy can observe connection metadata and timing.
- Tor and privacy guarantees depend strictly on the external proxy configuration; Root Wallet does not promise anonymity or untraceability.
- SOCKS5 routing does NOT encrypt plaintext TCP streams (`tcp://`).
- For encrypted Electrum transport over clearnet proxies, `ssl://` endpoints must be used.
- Root Wallet strictly enforces TLS domain certificate validation (`validateDomain: true`) for `ssl://` endpoints, preventing active TLS MITM attacks. Plaintext `tcp://` endpoints use `validateDomain: false`.
- For Tor hidden services, onion routing provides end-to-end circuit encryption at the Tor protocol level.

### Remote DNS Resolution
- Electrum target hostnames are resolved through the SOCKS5 proxy via SOCKS5 domain name addressing (`0x03`).
- Zero OS DNS queries applies specifically to the audited pinned `rust-electrum-client` SOCKS target path, preventing ISP/local network DNS leakage.

### Esplora Scoping & Custom Backend Disclosure
- Root Wallet supports custom Esplora endpoints in direct clearnet mode.
- When SOCKS5 is active, Esplora is completely bypassed because upstream BDK Esplora does not expose SOCKS5 proxying.
- Configured custom Esplora endpoints are NOT proxied under SOCKS5 and remain inactive until direct transport is restored.

### Address-Only Unauthenticated SOCKS5 Proxy
- The underlying BDK Rust FFI accepts an address-only SOCKS5 endpoint (`host:port`).
- To avoid deceptive security promises, Root Wallet does not present or persist unsupported username/password credentials.

### External Daemon Boundary
- Root Wallet deliberately does not bundle a compiled Tor binary or daemon, avoiding binary bloat, supply-chain expansion, and OS background lifecycle complications.
- Users connect to an external Tor daemon (e.g., Orbot on Android, `brew services start tor` on macOS, or a dedicated LAN proxy).
