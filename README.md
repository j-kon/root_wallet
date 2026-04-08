# Root Wallet

Root Wallet is a self-custody Bitcoin testnet wallet built with Flutter, Riverpod, and a feature-first clean architecture.

## What This Repo Covers

- Testnet wallet creation and restore
- Recovery phrase backup and confirmation
- Receive address + QR flow
- Send, review, broadcast, and transaction details
- App lock, PIN, biometrics, and recovery re-auth
- Light and dark liquid-glass UI system

## Core Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Visual Regression Workflow

The repo now has curated golden coverage for the highest-value UI surfaces:

- Main app shell and top-level tabs:
  - [main_shell_golden_test.dart](test/main_shell_golden_test.dart)
- Onboarding and security flows:
  - [onboarding_security_golden_test.dart](test/onboarding_security_golden_test.dart)

Run the golden suites:

```bash
flutter test test/main_shell_golden_test.dart
flutter test test/onboarding_security_golden_test.dart
```

Refresh golden baselines only when the visual change is intentional:

```bash
flutter test test/main_shell_golden_test.dart --update-goldens
flutter test test/onboarding_security_golden_test.dart --update-goldens
```

If a golden fails:

1. Check diff artifacts in `test/failures/`
2. Confirm the visual change is intentional
3. Update the golden only after reviewing the diff

## Golden Stability Notes

- Time-sensitive UI is frozen through [dateTimeNowProvider](lib/app/di/providers.dart) so relative-time labels do not make screenshots flaky.
- Main shell baselines live in `test/goldens/main_shell_*.png`
- Onboarding/security baselines live in `test/goldens/onboarding_security_*.png`

## Manual QA

Use the device checklist in [device_qa_checklist.md](docs/device_qa_checklist.md) before shipping UI-heavy changes.

## Architecture

- `lib/app`: app shell, routing, theme, global providers
- `lib/core`: shared platform, security, error, and widget infrastructure
- `lib/features`: feature modules split into presentation/domain/data
- `lib/shared`: cross-feature widgets, models, and extensions

## Current Network Assumption

The wallet is currently configured around public Bitcoin testnet flows and public testnet explorer links.
