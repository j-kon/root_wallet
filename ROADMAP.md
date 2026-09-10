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
- [x] **Authenticated Backup V2:** Upgraded metadata backup encryption to **AES-256-GCM** with HKDF-SHA256, eliminating padding oracle risks.
- [x] **Mnemonic Lifecycle:** Ephemeral seed generation with prompt memory nullification after onboarding confirmation.
- [x] **Privacy Shields:** App-switcher snapshot shielding on iOS and Android screenshot blocking during phrase review.
- [x] **Auto-Clearing Clipboard:** Sanitizes sensitive seed words from clipboard after 60 seconds.
- [x] **Compile-Time Safety Lock:** Explicit network assertion locking mainnet (`AppConstants.isMainnetAllowed = false`).
- [x] **Sanitized Logging:** Stripped all debug prints across codebase.
- [x] Dedicated automated CI security test suite (`test/security/`).

---

## Phase 3: Open-Source Public Foundation  
**Status: CURRENT MILESTONE 🚀**

- [x] Public repository audit and open-source readiness assessment.
- [x] License evaluation (Dual MIT OR Apache-2.0 recommendation).
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
- [ ] **Formal Mainnet Activation:** Remove compile-time testnet assertions after security sign-off.

---

## Phase 6: Advanced Bitcoin Capabilities  
**Status: FUTURE RESEARCH 🔭**

- [ ] **Hardware Wallet Integration:** USB/NFC integration with dedicated hardware signing devices (Coldcard, Jade, BitBox02, Foundation Passport).
- [ ] **Air-Gapped PSBT Tooling:** Partially Signed Bitcoin Transaction export/import via animated QR codes.
- [ ] **Watch-Only Wallets:** Read-only descriptor and extended public key (`xpub`/`ypub`/`zpub`) tracking.
- [ ] **Miniscript & Multi-Sig:** Advanced custody policies utilizing BDK’s native Miniscript compiler.

---

*Note: Feature scopes and order are subject to refinement based on community feedback, protocol developments, and security audit outcomes.*
