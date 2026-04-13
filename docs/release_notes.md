# Release Notes

## 2026-04-13

This release turns Root Wallet into a substantially more complete public-testnet wallet experience, with a stronger product surface, cleaner developer workflow, and better release confidence.

## Highlights

### Wallet foundation

- Public Bitcoin testnet wallet flows built around `bdk_flutter`
- Create wallet and restore wallet onboarding
- Recovery phrase backup and confirmation
- Persistent wallet state and cached wallet snapshot support
- Balance, activity list, transaction details, and explorer handoff

### Send and receive

- Receive address generation with QR rendering
- Copy and share support for raw addresses and `bitcoin:` payment URIs
- QR scanning for send flows with `mobile_scanner`
- Send form with validation, fee selection, review, success, and transaction follow-through
- Public testnet explorer integration for post-broadcast verification

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
- Users can receive testnet bitcoin, scan payment requests, review sends, and inspect transactions
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

## Known constraints

- The project depends on a Flutter toolchain compatible with Dart `3.10.x`
- Native-asset behavior still depends on local Flutter tooling being configured correctly
- Public testnet backend availability can affect sync latency and timing

## Recommended release QA

Before cutting or promoting a build, run the checklist in [device_qa_checklist.md](device_qa_checklist.md), with extra attention on:

- onboarding create and restore paths
- backup confirmation
- receive QR readability
- send review and success flow
- app lock resume behavior
- light and dark mode contrast on compact screens

## Suggested release summary

Root Wallet now ships a coherent self-custody Bitcoin testnet experience with production-style onboarding, send/receive flows, security controls, visual regression coverage, and polished cross-theme UI.
