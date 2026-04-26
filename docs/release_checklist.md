# Release Checklist

Use this checklist before tagging or promoting a Root Wallet build.

## Code Health

- `flutter analyze --no-pub` passes.
- `flutter test --no-pub --exclude-tags golden` passes.
- Golden tests are refreshed only intentionally and reviewed visually.
- No generated build artifacts are staged.

## Wallet Safety

- Create wallet, backup confirmation, and restore wallet flows work.
- Recovery phrase reveal requires re-auth when app lock is enabled.
- Delete local wallet requires confirmation and re-auth for protected wallets.
- Wallet reset clears cache, local labels, preferences, secure wallet metadata,
  and the BDK database.

## Testnet Behavior

- The app labels user-facing network surfaces as Testnet.
- Esplora sync uses `https://mempool.space/testnet/api` unless a dev override
  is intentionally configured.
- Explorer links open `https://mempool.space/testnet`.
- Send review uses BDK-backed fee preview before broadcast.

## Mobile Platform Review

- Android/iOS permission copy matches [mobile_permissions.md](mobile_permissions.md).
- Native splash assets are regenerated after splash config changes.
- Camera permission is requested only from the scan flow.
- Biometric prompts are only shown after the user opts in.

## Product QA

- Light and dark mode are readable on compact screens.
- Receive QR renders with sufficient contrast.
- Send success shows a pending transaction and explorer handoff.
- Transaction details show confirmations, manual refresh, TXID copy, explorer,
  and private note support.
- Diagnostics copy excludes recovery phrase, PIN, and private key material.
