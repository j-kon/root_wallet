# Contributing to Root Wallet

Welcome, and thank you for your interest in contributing to Root Wallet!

Root Wallet is an open-source, self-custodial, Bitcoin-only mobile wallet built with Flutter and powered by the Bitcoin Dev Kit (BDK). We hold our codebase to the highest standards of cryptographic correctness, clean architecture, privacy preservation, and intentional design.

Before submitting code, please review these guidelines.

---

## 1. Project Philosophy & Core Principles

Every contribution must honor Root Wallet's foundational principles:

- **Bitcoin-Only:** We focus exclusively on the Bitcoin network. We do not support, endorse, or integrate altcoins, tokens, smart-contract platforms, or Web3 multi-chain abstractions.
- **Self-Custody From the Root:** The user must hold absolute control over their private keys. Seed phrases and descriptors must never touch third-party servers.
- **Privacy by Design:** Zero analytics, zero third-party telemetry, zero user tracking. Network operations must be transparent, with minimal digital footprint.
- **Testnet-First:** While under active security hardening and community audit, Root Wallet remains strictly locked to Bitcoin Testnet and Signet. Mainnet enablement is intentionally blocked until all security prerequisites are verified.
- **No Unnecessary Complexity:** No speculative financial tools, yield programs, custodial swaps, or promotional banners. We build durable software for owning Bitcoin.

---

## 2. Environment & Toolchain Prerequisites

To build and test Root Wallet locally, your workstation must have:

### A. Flutter & Dart SDK
Root Wallet targets Flutter using FVM (Flutter Version Management).
- **Pinned Version:** Specified in [`.fvmrc`](.fvmrc) (Flutter `3.41.4`, Dart `^3.10.7`).
- Install dependencies:
  ```bash
  flutter pub get
  ```

### B. Rust & Cargo Toolchain
Because Root Wallet integrates `bdk_dart` (which compiles Rust native FFI assets for cryptographic operations and descriptor logic), you must have Rust and Cargo installed:
- **Recommended Rust Version:** `1.85.1` (or compatible stable toolchain).
- Verify:
  ```bash
  rustc --version
  cargo --version
  ```
- **Native Assets:** Flutter native assets are enabled. If an upstream dependency resolves an incompatible crate during development, restore our pinned lockfile:
  ```bash
  for dir in ~/.pub-cache/git/bdk-dart-*/native; do
    [ -d "$dir" ] && cp tool/ci/bdk_dart_Cargo.lock "$dir/Cargo.lock"
  done
  ```

---

## 3. Strict Design System: Solid Colors Only

> [!IMPORTANT]
> **Root Wallet enforces an absolute visual rule: SOLID COLORS ONLY.**

To maintain a calm, premium, and trustworthy user experience, we strictly reject decorative "crypto aesthetic" fads.

**Strictly Forbidden in Root Wallet:**
- ❌ **NO Gradients:** Do not use `LinearGradient`, `RadialGradient`, or gradient text/borders.
- ❌ **NO Glassmorphism / Blur:** Do not use `BackdropFilter` or translucent glass blur backgrounds.
- ❌ **NO Glow Effects:** Do not use glowing box shadows, glowing buttons, or neon borders.
- ❌ **NO Decorative Crypto Gimmicks:** No floating coins, 3D rotating Bitcoin logos, or Web3 particle animations.

**Approved Design Practice:**
- All UI surfaces must draw from the official flat brand tokens in [`lib/app/theme/brand/root_brand_colors.dart`](lib/app/theme/brand/root_brand_colors.dart):
  - `RootBrandColors.charcoalPine` (`#101917`) — Dark mode scaffold background
  - `RootBrandColors.nightPine` (`#0E1F1B`) — Dark mode card and surface fill
  - `RootBrandColors.deepForest` (`#162722`) — Dark mode input field fill
  - `RootBrandColors.pineGreen` (`#2AAE7F`) — Primary action accent
  - `RootBrandColors.warmIvory` (`#F4F5F1`) — Light mode scaffold & dark text primary
  - `RootBrandColors.pureWhite` (`#FFFFFF`) — Light mode card fill
  - `RootBrandColors.amberAccent` (`#E5A93C`) — Restrained Bitcoin warning/secondary highlight
  - `RootBrandColors.borderPine` (`#29403A`) — Dark mode subtle borders
- Use the standard [`AppScaffold`](lib/core/widgets/app_scaffold.dart) for all top-level views to guarantee correct status bar contrast across light and dark themes.

---

## 4. Architecture & Boundary Rules

Root Wallet follows a feature-first clean architecture:
- `lib/core/`: Reusable primitives, hardware wrappers, cryptographic utilities, network isolation guards.
- `lib/features/<feature>/`:
  - `data/`: Repositories, external service wrappers, local database DAOs.
  - `domain/`: Pure Dart entities, value objects, use cases.
  - `presentation/`: Riverpod controllers (`AsyncNotifier`), state classes, and presentation widgets.
- `lib/app/`: Top-level routing, DI configuration, themes, lifecycle security gate.

**Key Coding Rules:**
1. **Never Call BDK or Network APIs Directly in Widgets:** All business logic, BDK interactions, and network calls must be mediated through Riverpod providers (`ref.read(...)` or `ref.watch(...)`).
2. **Never Log Sensitive Material:** Never use raw `print()` statements. Use `AppLogger` where appropriate, and never log mnemonics, private keys, descriptors with secrets, or PINs.
3. **Wipe Secret State Promptly:** Seed phrases must only live in memory for the duration of the user view or confirmation action, and must be set to `null` immediately after.

---

## 5. Development Workflow

### Step 1: Create a Feature Branch
Branches should branch off `main` and follow standard naming:
```bash
git checkout main
git pull origin main
git checkout -b feature/your-feature-name
# or: fix/your-bug-fix
# or: docs/your-documentation-update
```

### Step 2: Conventional Commits
Write clear, imperative commit messages:
- `feat(wallet): implement coin selection preview`
- `fix(send): validate dust threshold before building transaction`
- `docs(security): document entropy generation source`
- `test(pin): add boundary check for 6-digit lockout`

### Step 3: Run Static Analysis & Verification
Before pushing, ensure static analysis and tests pass completely:

```bash
# 1. Run Flutter static analysis (must report zero issues)
flutter analyze

# 2. Run dedicated security test suite
flutter test test/security/

# 3. Run all unit and regression tests (excluding hosted goldens)
flutter test --exclude-tags golden
```

### Step 4: Golden Baselines (When UI Changes)
If your PR intentionally modifies UI layout or typography:
1. Run local golden tests:
   ```bash
   flutter test test/main_shell_golden_test.dart
   flutter test test/onboarding_security_golden_test.dart
   ```
2. If the visual change was intentional, update the baselines and inspect the image diff:
   ```bash
   flutter test test/main_shell_golden_test.dart --update-goldens
   flutter test test/onboarding_security_golden_test.dart --update-goldens
   ```
3. Attach before/after screenshots to your Pull Request.

---

## 6. Submitting a Pull Request

1. Push your branch to GitHub.
2. Open a Pull Request against `main`.
3. Complete all sections of the [Pull Request Template](.github/pull_request_template.md).
4. Clearly state whether your PR has any **Security Impact** (None, Security-Sensitive, or Requires Architecture Review).
5. Ensure CI passes completely on your PR.

---

## 7. Security Vulnerabilities

> [!CAUTION]
> **DO NOT report security vulnerabilities or cryptographic concerns through public GitHub issues.**

For responsible security disclosures, refer to our [Security Policy](SECURITY.md) and contact the core security team privately at `security@rootwallet.app`. We acknowledge vulnerability reports within 24 hours.
