# Development Guide

This guide is for engineers working in the Root Wallet repo.

## Local Setup

1. Install a Flutter version that bundles a Dart SDK compatible with:

```yaml
sdk: ^3.10.7
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

## Recommended Daily Workflow

Use a predictable loop:

1. make a focused change
2. format touched files
3. run analysis
4. run relevant tests
5. update goldens only if visuals changed intentionally
6. do a device sweep for UI-heavy work

## Commands

### Format

```bash
dart format lib test
```

### Analyze

```bash
flutter analyze
```

### Test

```bash
flutter test
```

### Targeted Goldens

```bash
flutter test test/main_shell_golden_test.dart
flutter test test/onboarding_security_golden_test.dart
```

### Update Golden Baselines

```bash
flutter test test/main_shell_golden_test.dart --update-goldens
flutter test test/onboarding_security_golden_test.dart --update-goldens
```

## Coding Expectations

### Keep boundaries clean

Do not place:
- BDK calls in widgets
- storage calls in widgets
- network calls in widgets

Widgets should consume providers, not systems.

### Prefer shared design-system changes

If multiple screens look off:
- check theme tokens first
- check `GlassSurface`
- check shared widgets

Only patch an individual screen when the issue is truly local.

### Avoid feature leakage

If a change belongs to one feature:
- keep it under that feature

If a change is reused across features:
- promote it to `shared` or `core`

## Riverpod Expectations

Use Riverpod as the source of truth for app state.

Prefer:
- `AsyncNotifier` for async screen state
- `StateNotifier` for form or multi-step state

Avoid pushing important business state into local widget state unless it is strictly visual and ephemeral.

## UI Workflow

When doing UI work:

1. verify light mode
2. verify dark mode
3. verify compact widths
4. verify the floating nav and safe areas
5. update goldens if the visual change is intentional

## Before Pushing

Minimum expectation:

```bash
flutter analyze
flutter test
```

If visual changes were made, also run:

```bash
flutter test test/main_shell_golden_test.dart
flutter test test/onboarding_security_golden_test.dart
```

## Branching

If you are already on an active working branch, keep related work together there.

If you are starting fresh from the integration branch, create a focused branch before making changes.

## Commit Quality

Prefer commits that are:
- scoped
- reviewable
- descriptive

Good commit messages explain the real change, not just the area touched.
