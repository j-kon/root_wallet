# Root Wallet: Product Positioning & Philosophy

**Core Brand Statement:** "Own Bitcoin from the root."  
**Supporting Message:** "Open-source self-custody, without the noise."  
**Primary Value Proposition:** Beginner-friendly on the surface. Powerful underneath.

---

## 1. What Root Wallet Is

Root Wallet is a modern, self-custodial, open-source Bitcoin wallet built for sovereign individuals who refuse to compromise on security, privacy, or usability. Powered by the Rust-based Bitcoin Dev Kit (BDK) and built with Flutter, Root Wallet bridges the gap between accessible everyday spending and deep cryptographic transparency.

### Core Pillars
1. **Bitcoin-Only:** We exclusively focus on the Bitcoin monetary network. We do not participate in altcoin speculation, DeFi tokens, or cross-chain ecosystems.
2. **True Self-Custody:** Private keys and recovery phrases are generated locally on-device and designed to remain on the device under the user's control. Users hold full sovereign ownership of their money.
3. **Radical Privacy:** Zero telemetry, zero third-party analytics trackers, zero KYC identity gates, and zero mandatory account creation.
4. **Noise-Free Design:** Built like an intentional editorial tool. We use solid, calm brand colors (`#101917`, `#2AAE7F`, `#F4F5F1`) and completely reject flashing graphics, speculative tickers, and gamified casino features.

---

## 2. What Root Wallet Is NOT (Explicit Non-Goals)

To preserve focus and maintain a focused and verifiable security boundary, Root Wallet will not become:

- ❌ **A Crypto Exchange or Brokerage:** We do not broker trades, maintain fiat-onramps, or execute custodial swaps.
- ❌ **A Trading App:** We do not provide speculative price charting, leveraged trading, or portfolio volatility graphs.
- ❌ **A Web3 / Multi-Chain Wallet:** We do not support EVM chains, Solana, ERC-20 tokens, NFT marketplaces, or browser dApp injection.
- ❌ **A Custodial Service:** We do not hold funds, manage custodial accounts, or store user seed phrases on remote cloud servers.

---

## 3. Product Hierarchy: Two Layers of Experience

Root Wallet provides a dual-layer experience that avoids overwhelming newcomers while ensuring experienced Bitcoiners have granular control over their transactions:

```
┌─────────────────────────────────────────────────────────┐
│                       SIMPLE MODE                       │
│      Everyday, intuitive self-custodial Bitcoin flows   │
│  Balance • Send • Receive • History • Backup • Security │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                  ADVANCED CAPABILITIES                  │
│       Granular on-chain power tools on demand           │
│  Taproot • SegWit • Coin Control • UTXO Lock • RBF      │
│     Fee Control • Diagnostics • Custom Endpoints        │
└─────────────────────────────────────────────────────────┘
```

### Layer 1: Simple Mode (The Primary Experience)
Newcomers to Bitcoin self-custody are guided by clean, uncluttered, and protective interfaces:
- **Clean Balance Display:** SATS and BTC denominational toggles with clear synchronization status.
- **Effortless Send & Receive:** Fast QR camera scanning, address parsing, and native sharing.
- **Protected Onboarding & Backup:** Step-by-step 12-word recovery phrase verification with explicit physical storage acknowledgement.
- **Frictionless App Lock:** Local PIN protection with biometric Face ID / Fingerprint convenience.

### Layer 2: Advanced Capabilities (Power Tools on Demand)
When users require deeper transaction control, Root Wallet unlocks specialized on-chain capabilities without cluttering the primary view:
- **Script Type Selection:** Seamless switching between Native SegWit (P2WPKH, `tb1q...`) and Taproot (P2TR, `tb1p...`).
- **Granular Coin Control:** UTXO inspection, individual output selection, and the ability to freeze or lock specific UTXOs to preserve financial privacy and prevent address clustering.
- **Replace-By-Fee (RBF):** Bumping transaction fee rates directly when mempool congestion spikes.
- **Custom Bitcoin Infrastructure:** Connecting directly to sovereign backend endpoints (custom Esplora or Electrum servers).
- **Future Capabilities:** Tor/SOCKS5 network proxy routing, watch-only public descriptor wallets, and Partially Signed Bitcoin Transactions (PSBT) for air-gapped hardware signing.

---

## 4. Target Audience

1. **The Sovereign Beginner:** Someone who wants to withdraw their Bitcoin from a custodian or exchange and take real self-custody for the first time, without getting overwhelmed by confusing blockchain jargon.
2. **The Principled Bitcoiner:** An experienced user who demands source code transparency, BDK lineage, zero analytics trackers, and coin control, but desires a fast, polished mobile daily driver.
3. **Open-Source Contributors & Researchers:** Developers seeking a clean, well-architected Flutter codebase built with robust Riverpod state management and Rust FFI.

---

## 5. Architectural Clarification

> [!NOTE]
> This document defines product positioning, feature tiering, and messaging boundaries. It does not mandate a dedicated "Simple/Advanced" UI toggle switch. Advanced tools are seamlessly embedded into contextual screens (e.g. Coin Control inside Send, Script Selection inside Receive, Node Configuration inside Settings).
