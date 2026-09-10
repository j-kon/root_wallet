# Root Wallet: Website Content & Design Specification

**Target Milestone:** Official Website / Landing Page  
**Status:** DESIGN & COPY SPECIFICATION (DO NOT IMPLEMENT CODE YET)  
**Primary Domain:** `rootwallet.app`  

---

## Part I: Design Direction & Visual System

Root Wallet’s web presence must feel like it was crafted by a world-class product design studio. It stands in stark, dignified contrast to the chaotic, hyperactive aesthetic of speculative Web3 websites.

### 1. The Core Visual Rule: Solid Colors Only

> [!IMPORTANT]
> **ABSOLUTELY ZERO GRADIENTS, GLASSMORPHISM, OR GLOW EFFECTS.**  
> The landing page must enforce the exact brand discipline of the mobile application.

**Strict Prohibitions:**
- ❌ **NO Gradients:** No linear or radial background gradients, no gradient text, no gradient borders.
- ❌ **NO Glassmorphism:** No CSS `backdrop-filter: blur()`, no simulated frosted glass panels.
- ❌ **NO Glow Blobs or Neon Haloes:** No glowing box-shadows, pulsing neon outlines, or cosmic nebula graphics.
- ❌ **NO Floating / 3D Bitcoin Coins:** No plastic or metallic 3D coins spinning in space.
- ❌ **NO Web3 / Crypto Tropes:** No particle networks, matrix rain, rocket emojis, or AI-generated fantasy illustrations.

### 2. Approved Brand Palette & Tokens

All layout backgrounds, containers, text, and interactive elements must utilize the official flat color tokens:

| Token Name | Hex Code | Primary Web Role |
|---|---|---|
| **Charcoal Pine** | `#101917` | Dark mode page background & primary dark surface |
| **Night Pine** | `#0E1F1B` | Secondary dark container / feature card fill |
| **Deep Forest** | `#162722` | Tertiary dark container / input background |
| **Border Pine** | `#29403A` | Crisp, razor-thin card and divider borders (1px) |
| **Pine Green** | `#2AAE7F` | Primary brand accent, primary buttons, verified badges |
| **Warm Ivory** | `#F4F5F1` | Primary light background & high-contrast dark text |
| **Pure White** | `#FFFFFF` | Light mode card containers & button text |
| **Amber Accent** | `#E5A93C` | Restrained Bitcoin accent (used sparingly for highlights) |
| **Muted Sage** | `#8E9E96` | Subtitles, captions, metadata, and secondary links |

### 3. Editorial & Typography Principles
- **Atmosphere:** Editorial, minimal, technical, calm, confident, and enduring.
- **Typography:** High-legibility modern grotesque sans-serif for headings (e.g., Inter, Space Grotesk, or Satoshi) paired with crisp monospace styling for code, hashes, and technical specs (e.g., JetBrains Mono).
- **Spacing:** Generous, intentional whitespace (80px–120px section padding) to allow each idea to breathe.
- **Imagery:** Real, authentic application screenshots captured directly from our golden UI baselines. No artificial device mockups with distorted perspective.
- **Brand Identity:** The distinctive Root Wallet "R" mark remains the dominant visual identifier across the navigation and favicon.

---

## Part II: Page Structure & Copywriting Specification

### Section 1: Top Navigation Bar
- **Brand Mark:** Root Wallet Logo ("R" glyph + "Root Wallet" wordmark in Warm Ivory).
- **Navigation Links:**
  - Product (`#product`)
  - Security (`/security` or `#security`)
  - Open Source (`#open-source`)
  - Roadmap (`#roadmap`)
  - GitHub (External link with star counter)
- **Primary CTA:** `Join Testnet` (Links to instructions / testing track).
  - *Rule: Never say "Download" or "Buy Bitcoin" while in testnet development.*

---

### Section 2: Hero Section
- **Headline:**  
  `Own Bitcoin from the root.`
- **Supporting Subheading:**  
  `An open-source, self-custody Bitcoin wallet built with the Bitcoin Dev Kit. Sovereign, noise-free, and engineered for privacy from the first block.`
- **Call-to-Action Group:**
  - Primary Button: `Join Testnet` (Solid Pine Green button with white text)
  - Secondary Button: `View Source` (Subtle 1px Border Pine outline with Warm Ivory text and GitHub icon)
- **Hero Visual:**  
  Clean, orthographic mockups showing Root Wallet running on iOS and Android:
  - Displaying the real Wallet Home screen and Receive screen.
  - Displaying clear Testnet indicators (e.g., `sats`, `tb1q...`).
  - Zero fake balances that could be mistaken for a real user's wallet.

---

### Section 3: Trust Strip
A restrained 4-column horizontal banner with minimal icons and high-contrast labels:
1. **Open Source:** 100% public code. Verify every commit.
2. **Self Custody:** Your keys, your rules. Zero custodial intermediaries.
3. **Bitcoin Only:** Focused entirely on sound money. No altcoin distractions.
4. **Built with BDK:** Powered by the industry-standard Rust Bitcoin Dev Kit.

---

### Section 4: Why Root Wallet?
A 3-column architectural breakdown explaining our core philosophy:

#### Card 1: Your Keys
`Generated on your device. Stored in hardware secure enclaves. Never shared, synced, or backed up to remote clouds without explicit authenticated encryption.`

#### Card 2: Your Bitcoin
`Direct interaction with the Bitcoin network. Generate native SegWit or Taproot addresses, inspect your UTXOs, and control network transaction fees.`

#### Card 3: Your Control
`Zero user accounts. Zero analytics trackers. Zero intrusive identity checks. Complete financial sovereignty in a clean, high-performance interface.`

---

### Section 5: The Product Experience
High-resolution UI feature showcases displaying actual application screenshots:

1. **Wallet Overview:** Instant balance tracking in SATS or BTC, cached offline state, and transparent sync status.
2. **Send with Precision:** Real-time fee estimation, camera QR code scanning, and explicit transaction review.
3. **Receive Securely:** Dynamic address generation, BIP-21 URI formatting, and native sharing.
4. **Transparent History:** Detailed transaction inspector with direct links to open-source block explorers.
5. **Recovery Phrase Shield:** Guided 12-word BIP-39 mnemonic verification with physical storage acknowledgement.
6. **Hardware Lock:** Argon2id memory-hard PIN gate with biometric Face ID / Touch ID convenience.

---

### Section 6: Advanced Bitcoin Capabilities
Highlighting power tools designed for experienced users:
- **Taproot & Native SegWit:** Toggle between P2TR and P2WPKH script types with a single tap.
- **Granular Coin Control:** Inspect individual UTXOs, freeze unspent outputs, and prevent address clustering.
- **Replace-By-Fee (RBF):** Adjust transaction fees after broadcast when network conditions fluctuate.
- **Custom Backend Nodes:** Override default indexers with your own personal home node (Esplora / Electrum).

---

### Section 7: Security Architecture
- **Headline:** `Security without the noise.`
- **Copy:**  
  `We don’t rely on marketing slogans like "bank-grade" or "unhackable." We rely on open cryptographic primitives, memory-safe Rust code, and defense-in-depth architecture.`
- **Key Points:**
  - **Argon2id KDF:** Resists GPU brute-force attacks with memory-hard PIN verification.
  - **AES-256-GCM Backups:** Authenticated encryption with tamper detection for all metadata exports.
  - **Multitasking Shielding:** Instant application obscuring in system app switchers.
  - **Auto-Clearing Clipboard:** Sensitive recovery words are wiped after 60 seconds.
- **Link:** `Read the full security model →` (Links to `/security` and `docs/security_model.md`).

---

### Section 8: Open Source Transparency
- **Headline:** `Don't trust us. Verify.`
- **Copy:**  
  `Every feature, cryptographic implementation, and commit in Root Wallet is open for public review, audit, and verification.`
- **Direct Links:**
  - [Source Code Repository](https://github.com/j-kon/root_wallet)
  - [Security Threat Model](https://github.com/j-kon/root_wallet/blob/main/docs/security_model.md)
  - [Security Audit Log](https://github.com/j-kon/root_wallet/blob/main/SECURITY_AUDIT.md)
  - [Contributor Guidelines](https://github.com/j-kon/root_wallet/blob/main/CONTRIBUTING.md)
  - [Development Roadmap](https://github.com/j-kon/root_wallet/blob/main/ROADMAP.md)

---

### Section 9: Bitcoin Dev Kit Foundation
- **Headline:** `Built on Bitcoin Dev Kit.`
- **Copy:**  
  `Root Wallet is proud to build on the foundational work of the Bitcoin Dev Kit community. By utilizing bdk_dart and core BDK Rust libraries, we inherit years of battle-tested, peer-reviewed Bitcoin engineering.`
- **Architecture Diagram:**
  ```
  Root Wallet (Flutter / Dart)
               ↓
    bdk_dart (Native C-ABI FFI)
               ↓
  Bitcoin Dev Kit (Rust Core)
               ↓
        Bitcoin Network
  ```
- *Disclaimer: Root Wallet is an independent open-source project built with BDK and is not officially endorsed by the BDK project maintainers.*

---

### Section 10: Current Status & Safety Notice
A prominent callout card styled with a crisp 1px Border Pine outline and Charcoal Pine fill:
- **Title:** `Current Status: Bitcoin Testnet`
- **Notice:**  
  `Root Wallet is currently in active development on the Bitcoin Testnet. Mainnet functionality is intentionally locked while cryptographic audits and security hardening are completed. Please do not attempt to store real funds.`

---

### Section 11: Final Call to Action
- **Headline:** `Take ownership from the root.`
- **Subheading:** `Join our public testnet beta, inspect the source code, and help us build the next generation of sovereign Bitcoin software.`
- **Buttons:**
  - `Join Testnet Beta`
  - `View on GitHub`
- **Footer:**
  - Copyright © 2026 Root Wallet Contributors.
  - Links to: Privacy Policy, Security Disclosure, Code of Conduct, Architecture, Roadmap.
  - Discrete notice: *"Bitcoin-only. Self-custodial. No telemetry."*
