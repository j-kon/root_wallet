# README Screenshot Guide

This folder stores the images used by the top-level [`README.md`](../../README.md).

## Current README images

These files are already wired into the README gallery:

- `welcome-light.png`
- `wallet-home-light.png`
- `receive-dark.png`
- `send-dark.png`
- `settings-dark.png`
- `security-light.png`

They are currently copied from the app's golden baselines so the README reflects the UI that is actually covered by tests.

## Recommended next screenshots

If you want to expand the README later, these are the best next screens to capture:

- `create-wallet-light.png`
- `backup-phrase-dark.png`
- `review-transfer-dark.png`
- `transaction-details-light.png`
- `lock-screen-dark.png`

## Naming convention

Use this format:

- `<screen-name>-<theme>.png`

Examples:

- `wallet-home-light.png`
- `receive-dark.png`
- `transaction-details-light.png`

## Capture guidance

Keep screenshots clean and product-facing:

- Use a compact iPhone simulator size for consistency
- Prefer realistic but non-sensitive sample wallet data
- Keep either light or dark mode intentionally, not mixed
- Avoid debug-only overlays if you are capturing manual screenshots
- Capture the primary part of the flow, not a half-transition state

## Good screens for README-quality storytelling

Use the README to tell the product story in this order:

1. Welcome
2. Wallet home
3. Receive
4. Send
5. Settings
6. Security

That sequence shows onboarding, core wallet use, and trust/safety controls without overwhelming the page.
