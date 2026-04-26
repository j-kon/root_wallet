# Mobile Permission Notes

Root Wallet should ask for the smallest permission set needed for a
self-custody Bitcoin wallet. Permissions should be explained near the feature
that needs them, not at app launch.

## Android

- Camera: required only for scanning payment QR codes in the send flow.
- Biometrics: used only when app lock or recovery phrase re-auth is enabled.
- Internet: required for public testnet sync, fee estimation, broadcast, and
  explorer/help links.
- Secure storage: used through the platform keystore for PIN hash material and
  wallet recovery metadata.

## iOS

- Camera: required only for scanning payment QR codes in the send flow.
- Face ID / Touch ID: used only when the user enables biometric app lock or
  sensitive-action re-auth.
- Network access: required for public testnet sync, fee estimation, broadcast,
  and explorer/help links.
- Keychain: used for wallet recovery metadata and PIN hash material.

## Product Rules

- Do not request camera permission until the user taps scan.
- Do not enable biometrics without explicit user consent.
- Do not log permission errors with wallet secrets or raw addresses.
- Keep recovery phrase screens protected from screenshots where the platform
  allows it.
