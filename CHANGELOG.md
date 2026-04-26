# Changelog

## Unreleased

### Product Trust
- Add a protected local wallet deletion flow that clears wallet state, cache, and backup/privacy flags after confirmation and re-auth.
- Make Root Wallet explicitly Testnet-facing across wallet copy, explorer links, and Esplora configuration.
- Add a recovery-phrase acknowledgement gate before seed confirmation so users confirm offline storage and recovery responsibility.
- Request Android screenshot protection while the recovery phrase screen is open.
- Clarify BDK network behavior: the current `bdk_flutter` version exposes `Network.testnet`, while Root Wallet points sync and explorer flows at Testnet infrastructure.

### UX / UI
- Add generated native Android and iOS splash assets through `flutter_native_splash`.
- Restore the Wallet home hero headline for a stronger first screen hierarchy.
- Polish native Android and iOS launch surfaces so they transition into the animated splash without a plain white flash.
- Reuse the branded splash while security state initializes to avoid startup visual jumps.
- Add cache age to the Wallet home offline status chip.
- Expand README screenshots with create-wallet, backup phrase, and app-lock surfaces.
- Add transaction-details “last checked” context.
- Add local-only address labels and transaction notes for safer human context.
- Add version/build visibility to the About surface.

### Engineering Quality
- Add BDK-backed send preview plumbing so review screens can use wallet-built fee estimates before broadcast.
- Pin CI/local handoff to Flutter `3.41.4` with `.fvmrc`.
- Add CI coverage for `flutter analyze` and `flutter test`.
- Add wallet diagnostics for backend, cache, network, and wallet database state.
- Track the last backend failure and support a dev-only custom Esplora endpoint override.
- Add release checklist and mobile permission notes.
- Add Testnet configuration assertions.
- Ignore and remove generated Gradle `buildSrc` artifacts from source control.
- Keep UI-facing wallet copy aligned with the current Testnet environment.
