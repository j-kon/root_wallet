# Root Wallet Privacy Policy (Draft for Review)

**Document Status:** DRAFT FOR LEGAL & COMMUNITY REVIEW  
**Effective Date:** September 10, 2026  
**Applicable Software:** Root Wallet Mobile Application (iOS & Android)  

> [!NOTE]
> This privacy policy accurately documents the technical behavior of Root Wallet. Root Wallet does not collect, sell, monetize, or harvest personal user data.

---

## 1. Core Privacy Architecture: No Accounts, No Telemetry

Root Wallet is built from the ground up as a decentralized, self-custodial software application:

- **No User Accounts:** You do not register with an email address, phone number, username, or password.
- **No Analytics SDKs:** Root Wallet contains **zero** third-party analytics trackers (no Google Analytics, no Firebase Analytics, no Mixpanel, no Amplitude).
- **No Crash Telemetry:** Root Wallet does **not** transmit crash dumps, stack traces, or device telemetry to remote error monitoring services (no Sentry, no Crashlytics).
- **No Advertising SDKs:** Root Wallet does **not** integrate ad networks, tracking pixels, or cross-app tracking identifiers.

---

## 2. Information Stored Exclusively on Your Device

All sensitive financial and cryptographic material is generated, processed, and stored locally within your device's isolated application sandbox:

1. **Recovery Phrases & Private Keys:** Recovery phrases and private keys are designed to remain on the device under user control, stored using platform secure storage (Apple Keychain on iOS and Android KeyStore on Android). Root Wallet communicates with Bitcoin network infrastructure solely for blockchain synchronization and transaction broadcasting.
2. **PIN & Biometric State:** Access PINs are not stored in plaintext. They are verified using an Argon2id memory-hard hash stored in platform secure storage. Biometric authentication (Face ID, Touch ID, Fingerprint) is handled entirely by the local operating system's LocalAuthentication API; biometric templates remain on your device.
3. **Wallet Databases & Transaction History:** Local SQLite databases caching UTXOs, transaction history, addresses, and local contact labels are stored locally in the application's sandboxed document directory.
4. **Encrypted Backups:** If you choose to export an encrypted backup, the file is encrypted locally using AES-256-GCM prior to being saved or shared by your operating system's standard share sheet.

---

## 3. Information Observed by External Bitcoin Infrastructure

Because Bitcoin is a public distributed peer-to-peer network, broadcasting transactions and syncing balances requires querying blockchain indexers.

### A. Public Backend Services (Esplora & Electrum)
By default, in the current testnet environment, Root Wallet queries public nodes (e.g., Blockstream Esplora and Electrum servers) over encrypted HTTPS/TLS connections:
- **What External Nodes Can Observe:**
  - Your device’s public IP address.
  - The Bitcoin addresses and script hashes your wallet queries to inspect balances and UTXOs.
  - Transactions you broadcast to the network.
- **What External Nodes CANNOT Observe:**
  - Your private keys, recovery phrases, or PINs.
  - Your device identity or real-world name.

### B. Block Explorer Links
When you tap "View in Explorer" on a transaction detail screen, Root Wallet opens the transaction identifier (`txid`) in your system browser (pointing to `mempool.space`). That request is subject to the external website's privacy policy.

### C. Sovereign Mitigation (Upcoming Roadmap)
To eliminate exposure of IP addresses and queried addresses to public indexers, Root Wallet is actively developing custom self-hosted node connections and native Tor/SOCKS5 network proxy routing.

---

## 4. Device Permissions

Root Wallet requests only the minimum operating system permissions strictly necessary to execute wallet functions:

- **Camera (`android.permission.CAMERA` / `NSCameraUsageDescription`):**  
  Used exclusively to scan Bitcoin payment request QR codes when sending funds or importing descriptors. Video frames are processed in local memory in real time and are never recorded, saved, or transmitted.
- **Biometrics (`USE_BIOMETRIC` / `NSFaceIDUsageDescription`):**  
  Used solely to authorize local wallet unlock and sensitive operations via your device's secure hardware.
- **Clipboard (`ClipboardService`):**  
  Used when you explicitly tap "Copy Address" or "Copy Recovery Phrase". For your security, sensitive copies (such as recovery phrases) are actively overwritten and sanitized from your system clipboard after 60 seconds.

---

## 5. Wallet Deletion & Data Erasure

When you perform a "Reset Wallet" action inside Settings:
- All primary and decoy SQLite databases (including write-ahead logs `.wal` and shared memory `.shm` files) are permanently wiped from device storage.
- All secure storage entries (keys, PIN verifiers, descriptors) are deleted from the iOS Keychain or Android KeyStore.
- Application preferences and cached snapshots are cleared.

---

## 6. Children’s Privacy

Root Wallet does not knowingly collect or solicit information from anyone under the age of 18. The software does not collect personal identity information from any user of any age.

---

## 7. Changes to This Policy

Any future revisions to this policy will be committed transparently to the public Root Wallet open-source repository.

---

## 8. Contact & Verification

If you have questions regarding this privacy policy or wish to inspect the implementation of our data handling in the open-source codebase:
- **Repository:** https://github.com/j-kon/root_wallet
- **Contact:** Contact the project maintainer privately using a verified contact method listed on the repository or open a public issue for general policy questions.
