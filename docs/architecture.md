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

## Persistence Model

The app uses multiple storage layers intentionally:

- `flutter_secure_storage`
  - PIN hash/salt
  - sensitive wallet metadata
- `shared_preferences`
  - non-sensitive app flags and preferences
- wallet persistence / snapshot cache
  - wallet and UI recovery state

## Test Strategy

The test strategy is layered:

- unit / controller tests for behavior
- widget tests for critical screens and interactions
- golden tests for high-value UI surfaces
- manual device QA for final sign-off

See [testing_and_qa.md](testing_and_qa.md) for the full workflow.
