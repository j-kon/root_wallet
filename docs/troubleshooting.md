# Troubleshooting

This document captures the failure modes we have already hit while working on Root Wallet.

## Flutter / Dart Version Mismatch

### Symptom

Commands fail before app logic runs, or package resolution fails with a Dart SDK complaint.

Example:

```text
The current Dart SDK version is 3.6.0.
Because root_wallet requires SDK version ^3.10.7, version solving failed.
```

### Cause

The local Flutter installation bundles an older Dart SDK than this repo requires.

### Fix

Upgrade Flutter to a version that includes a compatible Dart SDK, then rerun:

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
```

## Native Assets Not Enabled or Unavailable

### Symptom

Tests fail very early with native-assets errors.

Example:

```text
Package(s) objective_c require the native assets feature to be enabled.
```

### Cause

The current Flutter installation does not have native assets enabled, or the installed version reports the feature as unavailable.

### First attempt

```bash
flutter config --enable-native-assets
```

Then restart any open editors or terminals and rerun tests.

### If it still fails

Check:
- `flutter config --list`
- your Flutter version
- whether native assets are supported in that installed toolchain

If `enable-native-assets` shows as unavailable, the toolchain itself is the blocker.

## Analyzer Warnings From Lint Includes

### Symptom

`flutter analyze` shows warnings about unrecognized lint rules from included lint files.

### Cause

The local analyzer or lint package combination does not support the same rule set expected by the repo.

### Fix

Make sure the Flutter/Dart toolchain and lint package versions are compatible. If needed, keep analyzer config simple until the local environment is upgraded.

## Wallet Sync Failures

### Symptom

Home screen fails to sync or shows offline data.

### Current network assumptions

Root Wallet uses public Bitcoin testnet4 infrastructure:
- `https://mempool.space/testnet4/api`
- The app keeps the backend list intentionally small until additional public testnet4 Esplora mirrors are verified.

### Things to check

1. network connectivity
2. device date/time
3. backend availability
4. whether cached wallet snapshot data is being used as fallback

### In-app diagnostics

Open `Settings -> Wallet diagnostics` to inspect:
- active Esplora endpoint
- BDK network family
- wallet database path
- cache age and cached transaction count
- current wallet data state

The diagnostics payload is safe to copy because it excludes recovery words,
private keys, and raw transaction secrets.

## BDK / Native Runtime Initialization

### Symptom

Wallet creation or startup fails around native initialization.

### Cause

This is usually one of:
- missing native build artifact
- platform build misconfiguration
- incompatible local build environment

### Fix direction

1. verify the platform build succeeded fully
2. verify the native library is packaged
3. perform a clean rebuild:

```bash
flutter clean
flutter pub get
flutter run
```

## When In Doubt

Use this order:

1. confirm toolchain version
2. confirm dependency resolution
3. run analysis
4. run tests
5. inspect platform/native setup
6. inspect app-specific logic

That order saves a lot of time compared with debugging app code on a broken local toolchain.
