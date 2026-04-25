# Testing and QA

Root Wallet uses multiple layers of verification because a wallet app needs more than “it builds on my machine.”

## Test Layers

### 1. Static analysis

```bash
flutter analyze
```

This should be clean before any push.

### 2. Automated tests

```bash
flutter test --exclude-tags golden
```

The suite covers:
- controller behavior
- security flows
- send flow behavior
- receive interactions
- compact layout regressions

CI runs this non-golden suite. Golden tests are still part of the local visual
review workflow below.

### 3. Golden tests

Golden tests protect the main visual surfaces from silent regressions.
They are tagged as `golden` because strict image comparisons can vary across
Flutter patch versions and hosted runner renderers.

Current suites:
- [test/main_shell_golden_test.dart](../test/main_shell_golden_test.dart)
- [test/onboarding_security_golden_test.dart](../test/onboarding_security_golden_test.dart)

Run them:

```bash
flutter test test/main_shell_golden_test.dart
flutter test test/onboarding_security_golden_test.dart
```

Update only when the visual change is intentional:

```bash
flutter test test/main_shell_golden_test.dart --update-goldens
flutter test test/onboarding_security_golden_test.dart --update-goldens
```

### 4. Manual QA

Use the checklist in [device_qa_checklist.md](device_qa_checklist.md).

Manual QA matters especially for:
- wallet creation and restore
- recovery phrase flows
- send and receive
- dark mode
- compact devices
- app lock and resume behavior

## What To Verify For UI Changes

Always check:
- light theme
- dark theme
- compact width devices
- floating nav overlap
- safe-area behavior
- long text and button wrapping

## What To Verify For Wallet Changes

Always check:
- wallet creation
- wallet restore
- balance load
- receive address generation
- QR rendering
- send review and success flow
- transaction details

## What To Verify For Security Changes

Always check:
- enable app lock
- background and resume
- biometric path
- PIN path
- PIN mismatch handling
- cooldown behavior after repeated failures
- recovery phrase re-auth

## Golden Stability Notes

The app uses a deterministic time provider for relative-time labels so goldens do not drift because of “updated x minutes ago” text.

Reference:
- [providers.dart](../lib/app/di/providers.dart)

## Failure Triage

### If `flutter analyze` fails

1. fix actual code errors first
2. confirm the local Flutter/Dart version is compatible with the repo
3. check whether lint config is compatible with the local analyzer version

### If `flutter test` fails

1. identify whether it is:
   - app logic
   - widget behavior
   - golden mismatch
   - toolchain/native-assets startup
2. fix the root cause, not just the symptom

### If goldens fail

1. inspect `test/failures/`
2. verify the visual change is intentional
3. update baselines only after review

## Release-Quality Sign-off

A UI-heavy change is ready when:
- analysis passes
- tests pass
- goldens are updated only where intended
- manual device QA is complete
- no clipped, muddy, or unreadable states remain in light or dark mode
