# Changelog

## Unreleased

### Product Trust
- Make Root Wallet explicitly Testnet4-facing across wallet copy, explorer links, and Esplora configuration.
- Add a recovery-phrase acknowledgement gate before seed confirmation so users confirm offline storage and recovery responsibility.
- Request Android screenshot protection while the recovery phrase screen is open.
- Clarify BDK network behavior: the current `bdk_flutter` version exposes `Network.testnet`, while Root Wallet points sync and explorer flows at Testnet4 infrastructure.

### UX / UI
- Restore the Wallet home hero headline for a stronger first screen hierarchy.
- Polish native Android and iOS launch surfaces so they transition into the animated splash without a plain white flash.
- Reuse the branded splash while security state initializes to avoid startup visual jumps.
- Add cache age to the Wallet home offline status chip.
- Expand README screenshots with create-wallet, backup phrase, and app-lock surfaces.
- Add transaction-details “last checked” context.

### Engineering Quality
- Add CI coverage for `flutter analyze` and `flutter test`.
- Add wallet diagnostics for backend, cache, network, and wallet database state.
- Add Testnet4 configuration assertions.
- Ignore and remove generated Gradle `buildSrc` artifacts from source control.
- Keep UI-facing wallet copy aligned with the current Testnet4 environment.
