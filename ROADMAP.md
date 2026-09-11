# Root Wallet Roadmap

Root Wallet is being developed in deliberate, verifiable stages. Because we build self-custodial financial infrastructure, our timeline is driven by cryptographic verification, rigorous automated testing, and security hardening rather than arbitrary calendar deadlines.

---

## Phase 1: Testnet Wallet Foundation  
**Status: COMPLETED ✅**

- [x] Initial BDK Dart FFI integration (`bdk_dart` pinned to `v1.0.0-rc.2`).
- [x] Full Bitcoin Testnet transaction lifecycle: generate address, receive funds, calculate fees, build PSBT, sign, and broadcast.
- [x] Core wallet lifecycle: 12-word BIP-39 mnemonic creation, validation challenge, and recovery flow.
- [x] Riverpod-driven feature-first clean architecture.
- [x] Solid brand color design system redesign (retired glowing orbs and gradients).
- [x] Comprehensive visual regression golden suites for all primary app surfaces.

---

## Phase 2: Security Hardening & Threat Model Remediation  
**Status: COMPLETED / ONGOING REVIEW 🛡️**

- [x] **KDF Hardening:** Upgraded PIN verification from single-iteration SHA-256 to memory-hard **Argon2id** (`m=16MB, t=3, p=1`).
- [x] **Persistent Lockout:** Escalating delay ladder (2s → 5s → 15s → 60s → 300s) persisted in platform secure storage.
- [x] **Mnemonic Lifecycle:** Ephemeral seed generation with prompt state reference removal after onboarding confirmation.
- [x] **Privacy Shields:** App-switcher snapshot shielding on iOS and Android screenshot blocking during phrase review.
- [x] **Auto-Clearing Clipboard:** Sanitizes sensitive seed words from clipboard after 60 seconds.
- [x] **Network Safety Guard:** Mainnet disabled by a compile-time constant (`AppConstants.isMainnetAllowed = false`) and enforced by runtime network checks.
- [x] **Sanitized Logging:** Stripped all debug prints across codebase.
- [x] **Watch-Only Wallets & PSBT Lifecycle (Milestone 1):**
  - Watch-only wallet support using public descriptors (`wpkh`, `tr`, `sh(wpkh)`, `pkh`) and Testnet `tpub` without private key storage.
  - Fail-closed PSBT signing re-authentication with Argon2id PIN fallback.
  - Centralized PSBT input validation enforcing decoded binary limits (<= 500 KB) across inspect, sign, and broadcast.
  - Real Bitcoin unsigned transaction TxID extraction (no fabricated SHA-256 fallback hashes).
  - Authoritative change output classification (no heuristic guessing).
  - Finalization verification rejecting unfinalized PSBT broadcast.
  - Wallet-scoped BIP-329 label storage (`wallet.local_labels.v2.<scope>`) with deterministic v1 migration.
- [x] **Multi-Wallet Foundation & Wallet Switcher (Milestone 2A):**
  - Multiple signing and watch-only wallets with seamless active wallet switching.
  - Immediate BDK session recreation and Riverpod state isolation on switch.
  - Cryptographically isolated namespaces for BDK SQLite databases (`wallets/<wallet-id>/bdk_wallet.sqlite`), secure storage keys (`wallet.<wallet-id>.*`), BIP-329 labels (`wallet.local_labels.v3.<wallet-id>`), locked UTXOs (`wallet.<wallet-id>.locked_utxos`), and snapshot caches (`wallet.snapshot.<wallet-id>.v3`).
  - Deterministic idempotent single-wallet legacy migration to `w_primary_migrated`.
  - Interactive wallet switcher bottom sheet accessible from home screen header.
  - Wallets management center in Settings with wallet details, renaming, and authenticated deletion.
  - Last-wallet deletion protection and deterministic fallback switching.
  - Fail-closed sensitive action re-authentication required prior to signing wallet deletion.
- [x] Dedicated automated CI security test suite (`test/security/`).

---

## Phase 3: Open-Source Public Foundation  
**Status: CURRENT MILESTONE 🚀**

- [x] Public repository audit and open-source readiness assessment.
- [x] Formal open-source dual licensing adopted (MIT OR Apache-2.0).
- [x] Professional contributor guide (`CONTRIBUTING.md`) and Contributor Covenant (`CODE_OF_CONDUCT.md`).
- [x] Standardized GitHub Issue forms (bug reports, feature proposals, security questions) and Pull Request template.
- [x] Transparent public security model and user-facing `/security` website specification.
- [x] Comprehensive privacy policy draft distinguishing local vs. network-level metadata.
- [x] Website landing page content and editorial design specification.
- [x] Store submission readiness audit (iOS / Android checklist).
- [x] Repository branch protection and governance recommendations.

---

## Phase 4: Privacy Tooling & Network Sovereignty  
**Status: PLANNED 🔒**

- [ ] **Custom Node Configuration:** Allow users to connect directly to their personal home node (custom Esplora or Electrum endpoints).
- [ ] **Native Tor / SOCKS5 Proxy Support:** Route all wallet network queries and transaction broadcasts through the Tor anonymity network to conceal client IP addresses.
- [ ] **Coin Control Enhancements:** Granular UTXO label management, output tagging, and coin freezing to prevent accidental address clustering.
- [ ] **Mempool Privacy Enhancements:** Dandelion++ transaction propagation exploration and custom fee estimation sources.

---

## Phase 5: Mainnet Release Candidate  
**Status: PLANNED 🎯**

- [ ] **Independent Third-Party Audit:** Commission external cybersecurity firm to audit Rust FFI bindings, secure storage, and cryptographic primitives.
- [ ] **Production Store Identity:** Configure permanent reverse-domain application identifiers (`com.rootwallet.app`).
- [ ] **Secure Release Signing:** Provision offline hardware security keys for Google Play and Apple Developer distribution.
- [ ] **Public Beta Testing:** Launch coordinated TestFlight (iOS) and Google Play Internal Testing tracks.
- [ ] **Reproducible Build Pipeline:** Publish deterministic build instructions so researchers can independently verify binary checksums against source code.
- [ ] **Formal Mainnet Activation:** Enable mainnet configuration after independent security sign-off.

---

## Phase 6: Advanced Bitcoin Capabilities  
**Status: FUTURE RESEARCH 🔭**

- [ ] **Hardware Wallet Integration:** USB/NFC integration with dedicated hardware signing devices (Coldcard, Jade, BitBox02, Foundation Passport).
- [ ] **Air-Gapped PSBT Tooling:** Partially Signed Bitcoin Transaction export/import via animated QR codes.
- [ ] **Watch-Only Wallets:** Read-only descriptor and extended public key (`xpub`/`ypub`/`zpub`) tracking.
- [ ] **Miniscript & Multi-Sig:** Advanced custody policies utilizing BDK’s native Miniscript compiler.

---

*Note: Feature scopes and order are subject to refinement based on community feedback, protocol developments, and security audit outcomes.*
