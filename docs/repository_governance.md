# Root Wallet: Repository Governance & Branch Protection Guidelines

**Status:** RECOMMENDATION & BEST PRACTICES  
**Target Branch:** `main`  
**Applicability:** GitHub Repository (`j-kon/root_wallet`)  

> [!NOTE]
> This document outlines recommended repository settings for the repository owner. In accordance with security constraints, these settings are not applied automatically.

---

## 1. Objective

As a self-custodial Bitcoin wallet, Root Wallet’s source code repository directly impacts user fund security. A compromised commit, accidental force push, or unreviewed dependency bump on `main` could expose users to severe risk.

We recommend configuring GitHub Branch Protection Rules on the `main` branch to guarantee that every change is reviewed, verified by automated CI, and cryptographically attributable.

---

## 2. Recommended Branch Protection Rules for `main`

Navigate to **GitHub Repository → Settings → Branches → Add branch ruleset** (or Branch protection rule for `main`):

### 1. Require a Pull Request Before Merging
- **Rule:** Check `Require a pull request before merging`.
- **Required Approvals:** Require at least **1 approving review** from a code owner or core maintainer before merge.
- **Dismiss Stale Approvals:** Check `Dismiss stale pull request approvals when new commits are pushed`. If an author pushes new commits after a review, re-approval is mandatory.
- **Require Review from Code Owners:** Check `Require review from Code Owners` using a `.github/CODEOWNERS` file.

### 2. Require Status Checks to Pass Before Merging
- **Rule:** Check `Require status checks to pass before merging`.
- **Require Branches to be Up to Date:** Check `Require branches to be up to date before merging` (ensures code is tested against the latest HEAD of `main`).
- **Required Status Checks:**
  - `analyze-test` (from `.github/workflows/flutter.yml`):
    - `flutter analyze`
    - `Security Tests` (`flutter test test/security/`)
    - `Test` (`flutter test --exclude-tags golden`)

### 3. Block Direct Pushes & Prevent Force Pushes
- **Block Direct Pushes:** Disable direct `git push origin main` for all users (including repository administrators). All changes must arrive via approved Pull Requests.
- **Prevent Force Pushes:** Check `Block force pushes` to ensure git commit history remains immutable and append-only.
- **Prevent Branch Deletion:** Check `Do not allow branch deletion`.

### 4. Require Signed Commits (GPG / SSH)
- **Rule:** Check `Require signed commits`.
- **Benefit:** Guarantees that every commit merged into `main` is cryptographically signed by a verified maintainer GPG or SSH key, preventing author impersonation attacks.

### 5. Require Linear History
- **Rule:** Check `Require linear history`.
- **Benefit:** Keeps the commit log clean, easily readable, and bisectable using `Squash and merge` or `Rebase and merge`.

---

## 3. Recommended Multi-Tier Review Protocol

For PRs submitted to Root Wallet, we recommend a 3-tier review process:

| PR Tier | Example Changes | Review Requirements |
|---|---|---|
| **Tier 1: Non-Sensitive** | Documentation, README, code comments, copy tweaks | 1 standard code review + passing CI |
| **Tier 2: UI & Architecture** | Widget refactoring, theme changes, routing | 1 standard review + UI screenshots on light/dark mode + passing CI |
| **Tier 3: Security-Sensitive** | BDK version bumps, Argon2id parameters, AES-GCM backups, secure storage, network assertions | 2 maintainer reviews + explicit threat model review + passing CI security suite |

---

## 4. Release Tagging & Provenance

When preparing release candidates:
1. All release tags (e.g. `v1.0.0-rc.1`) must be annotated and cryptographically signed (`git tag -s`).
2. Release tags must trigger reproducible GitHub Release workflows that publish SHA-256 checksums of all build artifacts.
