# Device QA Checklist

Use this checklist for real-device or simulator sign-off after UI, navigation, or wallet-flow changes.

## Before You Start

1. Run `flutter analyze`
2. Run `flutter test`
3. If visuals changed, run the golden suites
4. Test both light and dark mode
5. Test at least one compact device profile

## Onboarding

1. Fresh install opens `Welcome`
2. `Create wallet` opens the create flow without layout issues
3. `Restore wallet` opens the restore flow without clipped controls
4. Back navigation behaves correctly throughout onboarding

## Create + Backup Flow

1. Create a wallet
2. `Back up phrase` shows the recovery phrase clearly
3. Phrase chips are readable and scroll if needed
4. `I wrote it down` continues to confirmation
5. Confirming the requested words reaches the main shell
6. `backupConfirmed` behavior updates correctly afterward

## Restore Flow

1. Paste a valid recovery phrase
2. Restore succeeds and routes correctly
3. Error copy is readable and friendly for invalid phrases

## Home / Wallet

1. Home loads without overflow in light mode
2. Home loads without overflow in dark mode
3. Balance card, action cards, and activity list render cleanly
4. Pull-to-refresh works
5. Sync state copy reads correctly
6. Network badge clearly shows `Testnet`

## Receive

1. QR renders with good contrast in light mode
2. QR renders with good contrast in dark mode
3. `Copy address`, `Copy URI`, and share action layout stay intact on compact widths
4. Warning banners remain readable in both themes

## Send

1. Recipient field, amount section, and fee selector fit on compact screens
2. QR scan entry path opens correctly
3. Review CTA enables only when form state is valid
4. Fee chips do not clip or truncate badly
5. Review screen shows amount, fee, total, and network clearly
6. Success screen shows TXID, explorer action, and return path cleanly

## Transaction Details

1. Activity row opens transaction details
2. Status pill, confirmations, amount, and TXID are readable
3. `View on explorer` works

## Settings / Security

1. Settings cards align cleanly in light and dark mode
2. Theme selector behaves correctly
3. Security screen loads without clipped toggles or dropdowns
4. Lock screen keypad fits compact widths
5. PIN and biometric flows remain usable after theme changes

## App Lock

1. Enable app lock
2. Background and resume the app
3. Lock screen appears
4. PIN entry works
5. Five wrong PIN attempts trigger cooldown
6. Biometrics path works when available

## Regression Guardrails

1. Run:

```bash
flutter test test/main_shell_golden_test.dart
flutter test test/onboarding_security_golden_test.dart
```

2. If either fails, inspect `test/failures/`
3. Update goldens only for intentional UI changes

## Sign-off

Release-ready UI should satisfy all of the following:

- No visible overflow or clipping
- No unreadable text in dark mode
- No broken compact-device layouts
- Golden tests pass
- Manual happy paths feel consistent from onboarding to send/receive/security
