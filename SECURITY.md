# Security Policy & Vulnerability Disclosure

Root Wallet takes security and user sovereignty seriously. As a self-custodial, Bitcoin-only wallet, the safety of user funds and private keys is our highest priority.

---

## 1. Supported Versions

Root Wallet is currently under active Testnet development.

| Version | Status |
|---|---|
| main / current Testnet development | Supported on a best-effort basis |
| tagged pre-releases | Supported when explicitly documented |
| Mainnet releases | Not yet available |

Root Wallet has not yet released a production Mainnet version.

---

## 2. Reporting a Vulnerability

We deeply appreciate responsible disclosure from security researchers, auditors, and the Bitcoin open-source community.

If you discover a security vulnerability, **please do NOT open a public GitHub issue**.

### Preferred Reporting Channel
- **GitHub Private Vulnerability Reporting:** Please use GitHub Private Vulnerability Reporting when available:
  `https://github.com/j-kon/root_wallet/security/advisories/new`
- **Maintainer Contact:** If private vulnerability reporting is temporarily unavailable, contact the project maintainer through a verified contact method listed on the repository.

### What to Include in Your Report
To help us evaluate and resolve the issue quickly, please provide:
1. **Description:** Clear explanation of the vulnerability and its potential impact.
2. **Steps to Reproduce:** Minimal reproduction steps, proof-of-concept (PoC) script, or test case.
3. **Affected Versions / Platforms:** Specify iOS, Android, macOS, or Linux, including OS versions if applicable.
4. **Proposed Fix (Optional):** Any recommended remediation or architectural fix.

---

## 3. Response & Resolution Commitments

We aim to acknowledge responsible security reports as soon as reasonably possible and will coordinate remediation and disclosure based on severity.

- **Patch Development:** Coordinated fixes developed in private repositories or security advisories.
- **Public Disclosure:** Coordinated release and disclosure schedule after a patch has been published and distributed to users.
- **Credit & Attribution:** We gladly credit researchers in release notes and changelogs (unless anonymity is requested).

---

## 4. Scope

### In-Scope
- Vulnerabilities leading to unauthorized exposure or theft of private keys, seeds, or PINs.
- Bypasses of PIN lock, biometrics, or duress wallet protection.
- Transaction tampering, unintended fee inflation, or address spoofing in PSBT generation.
- Cryptographic flaws in backup encryption, key derivation, or entropy generation.
- Data leaks across process or app boundaries (e.g. clipboard, app switcher previews).

### Out-of-Scope
- Attacks requiring root / jailbroken device access where the OS security sandbox is completely compromised.
- Social engineering, phishing, or physical coercion targeting the user.
- Denial of Service (DoS) against public third-party Esplora / Electrum backends outside of Root Wallet's control.
- Theoretical issues without demonstrable impact or working PoC.
