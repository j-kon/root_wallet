# Architecture

Root Wallet uses feature-first clean architecture with Riverpod orchestration.

The intent is simple:
- widgets render state
- providers orchestrate flows
- domain expresses business intent
- data integrates external systems

## Top-Level Layout

### `lib/app`

Application shell concerns:
- bootstrap
- routing
- theme
- global providers
- app-wide security gate

Examples:
- [bootstrap.dart](../lib/bootstrap.dart)
- [app_router.dart](../lib/app/routing/app_router.dart)
- [main_shell.dart](../lib/app/routing/main_shell.dart)

### `lib/core`

Cross-cutting building blocks:
- constants
- error mapping
- platform wrappers
- security helpers
- reusable widgets
- formatting and utility helpers

Examples:
- [app_constants.dart](../lib/core/constants/app_constants.dart)
- [error_mapper.dart](../lib/core/errors/error_mapper.dart)
- [glass_surface.dart](../lib/core/widgets/glass_surface.dart)

### `lib/features`

Each feature owns its own boundaries.

Examples:
- `wallet`
- `receive`
- `send`
- `settings`
- `onboarding`
- `rates`

Typical feature layout:

- `presentation`
  - pages
  - providers
  - feature widgets
- `domain`
  - entities
  - repositories
  - use cases
- `data`
  - datasources
  - mappers
  - repository implementations

### `lib/shared`

Code reused across features but not global enough for `core`:
- shared widgets
- extensions
- small shared models

## Boundary Rules

These rules matter and should remain stable.

### Presentation

Presentation is responsible for:
- widget composition
- user input collection
- navigation triggers
- provider consumption

Presentation must not:
- call BDK directly
- call storage directly
- call network APIs directly

### Domain

Domain is pure Dart.

Domain should contain:
- entities
- repository contracts
- use cases

Domain must not depend on Flutter UI.

### Data

Data owns the integrations:
- BDK wallet engine
- secure storage
- shared preferences
- URL launchers and share wrappers
- network-backed sync sources

Repository implementations belong here, not in widgets and not in the domain layer.

## State Ownership

Root Wallet uses Riverpod for state orchestration.

Typical patterns:
- `AsyncNotifier` for screen-backed async state
- `StateNotifier` for form state and multi-step flows

Examples:
- wallet home state
- send draft / review state
- lock state
- onboarding state

## Routing Model

Routing is centralized in:
- [routes.dart](../lib/app/routing/routes.dart)
- [app_router.dart](../lib/app/routing/app_router.dart)

The app shell uses a persistent bottom-nav container for:
- Wallet
- Receive
- Send
- Settings

Additional flows stack on top:
- onboarding
- review transfer
- success state
- transaction details
- security and about

## UI System

The current UI direction is a liquid-glass style with shared surface tokens.

Core UI primitives include:
- [AppScaffold](../lib/core/widgets/app_scaffold.dart)
- [GlassSurface](../lib/core/widgets/glass_surface.dart)
- theme tokens in [app_theme.dart](../lib/app/theme/app_theme.dart)
- color system in [colors.dart](../lib/app/theme/colors.dart)

The design system should be changed centrally whenever possible, not by tuning one screen at a time.

## Security Model

Security-sensitive responsibilities include:
- app lock enablement
- PIN storage and verification
- biometric authentication
- recovery phrase access gating

Sensitive material belongs behind providers and security services, never in presentation logic.

## Network Transport & Privacy Routing

Network routing follows a strict capability-gated, fail-closed architecture:

- `core/network/network_transport_config.dart`
  - `NetworkTransportMode`: `direct` (clearnet) or `socks5` (proxy), with strict fail-closed persisted parsing (`parsePersisted`).
  - `Socks5ProxyConfig`: host and port with strict normalization (IPv6 bracketed format `[::1]:port`, scheme/slash stripping), port bounds checking (1–65535), Tor v3 onion address validation, and target vs proxy separation (rejecting `.onion` in proxy host).
  - `NetworkConfiguration`: immutable global transport state.
- `features/settings/presentation/providers/network_transport_providers.dart`
  - `NetworkTransportController`: persists transport settings in `SharedPreferences` and probes connections using real BDK `ElectrumClient` via Rust FFI targeting the configured custom Electrum endpoint.
  - Invalidates `bdkWalletServiceProvider` upon transport mode or proxy configuration changes.
- `features/wallet/data/services/bdk_wallet_service.dart`
  - **Capability Gating:** Electrum supports native SOCKS5 proxying with remote DNS (`0x03` domain addressing) and `.onion` support. Esplora (`minreq` HTTP CONNECT only) is bypassed completely in SOCKS5 mode; configured custom Esplora endpoints are not proxied.
  - **Fail-Closed Guarantee:** When SOCKS5 is active, sync, fee estimation, transaction broadcast, and tip height queries fail immediately if the proxy is unreachable. Silent fallback to clearnet is strictly prohibited.
  - **Single-Backend Isolation:** When a custom Electrum server is set, failure never triggers fallback to public Electrum servers.
  - **TLS Domain Validation:** Strictly enforces domain certificate validation (`validateDomain: true`) for `ssl://` endpoints; plaintext `tcp://` endpoints use `validateDomain: false`.

## Persistence Model

The app uses multiple storage layers intentionally:

- `flutter_secure_storage`
  - PIN hash/salt
  - sensitive wallet metadata (seed phrases, script types)
- `shared_preferences`
  - non-sensitive app flags and preferences
  - SOCKS5 proxy host, port, and transport mode
- wallet persistence / snapshot cache
  - wallet and UI recovery state

## Test Strategy

The test strategy is layered:

- unit / controller tests for behavior
- widget tests for critical screens and interactions
- golden tests for high-value UI surfaces
- manual device QA for final sign-off

See [testing_and_qa.md](testing_and_qa.md) for the full workflow.
