# Release Notes

## 2026-04-13

This release turns Root Wallet into a substantially more complete public Testnet4 wallet experience, with a stronger product surface, cleaner developer workflow, and better release confidence.

## At a glance

### Best for

- engineers onboarding to the current wallet milestone
- testers validating public testnet4 behavior
- stakeholders reviewing what is actually ready in the app

### What matters most

- the app now supports a coherent end-to-end testnet4 journey:
  - onboarding
  - backup
  - receive
  - send
  - review
  - transaction follow-through
- security is no longer a placeholder surface:
  - PIN
  - biometrics
  - app lock
  - recovery phrase re-auth
- the UI now has a unified system across light and dark mode, backed by regression coverage

## Highlights

### Wallet foundation

- Public Bitcoin testnet4 wallet flows built around `bdk_flutter`
- Create wallet and restore wallet onboarding
- Recovery phrase backup and confirmation
- Persistent wallet state and cached wallet snapshot support
- Balance, activity list, transaction details, and explorer handoff

### Send and receive

- Receive address generation with QR rendering
- Copy and share support for raw addresses and `bitcoin:` payment URIs
- QR scanning for send flows with `mobile_scanner`
- Send form with validation, fee selection, review, success, and transaction follow-through
- Public testnet4 explorer integration for post-broadcast verification

### Security

- App lock with PIN support
- Optional biometric unlock and re-auth
- Recovery phrase reveal protection
- Backup confirmation flow and backup reminder support

### UI and product polish

- Liquid-glass light and dark themes
- Full-screen shell with floating bottom navigation
- Compact-width regression hardening across primary flows
- Golden coverage for main shell plus onboarding/security surfaces

### Engineering quality

- Clearer project documentation across architecture, development, testing, and troubleshooting
- Analyzer and test suite brought back to a green baseline
- Golden-failure artifacts removed from version control and ignored going forward

## What shipped in practice

### Product experience

- New users are routed through onboarding instead of landing in a broken wallet state
- Existing users land in the main shell with persistent wallet context
- Users can receive testnet4 bitcoin, scan payment requests, review sends, and inspect transactions
- Security-sensitive flows now feel integrated instead of bolted on

### Design system

- Shared glass surfaces, banners, cards, and action treatments are used consistently across:
  - wallet home
  - receive
  - send
  - settings
  - onboarding
  - security
  - transaction details

### Developer workflow

- Project docs now describe the architecture and verification expectations clearly
- QA guidance exists for both automated and manual sign-off
- Golden workflows are documented and easier to maintain

## Validation completed for this release

- `flutter analyze --no-pub`
- `flutter test --no-pub`
- golden refresh and verification for:
  - `test/main_shell_golden_test.dart`
  - `test/onboarding_security_golden_test.dart`
- simulator sanity launch on `iPhone 16e`

## 5-minute tester walkthrough

Use this if you want the fastest path to confidence:

1. Launch the app and confirm onboarding opens instead of a broken wallet shell
2. Create a wallet and complete backup confirmation
3. Open `Receive` and verify the QR and address copy/share actions
4. Open `Send`, paste or scan a testnet4 destination, and verify fee/review states
5. Confirm the success screen and transaction details flow
6. Open `Settings` and `Security`, then verify app lock controls and recovery reveal protection
7. Switch between light and dark mode and confirm the shell still reads cleanly

## Known constraints

- The project depends on a Flutter toolchain compatible with Dart `3.10.x`
- Native-asset behavior still depends on local Flutter tooling being configured correctly
- Public testnet4 backend availability can affect sync latency and timing

## Recommended release QA

Before cutting or promoting a build, run the checklist in [device_qa_checklist.md](device_qa_checklist.md), with extra attention on:

- onboarding create and restore paths
- backup confirmation
- receive QR readability
- send review and success flow
- app lock resume behavior
- light and dark mode contrast on compact screens

## Handoff references

- repo overview: [../README.md](../README.md)
- architecture: [architecture.md](architecture.md)
- development workflow: [development_guide.md](development_guide.md)
- testing and QA: [testing_and_qa.md](testing_and_qa.md)
- troubleshooting: [troubleshooting.md](troubleshooting.md)

## Suggested release summary

Root Wallet now ships a coherent self-custody Bitcoin testnet4 experience with production-style onboarding, send/receive flows, security controls, visual regression coverage, and polished cross-theme UI.
