# Privacy and Security Notes

Root Wallet is a self-custody testnet wallet. It is designed to keep wallet
secrets out of widgets, logs, diagnostics, screenshots, and support payloads.

## Secret Handling

- Recovery phrases are stored through the secure storage wrapper.
- PINs are never stored raw; the PIN service stores a salted hash.
- Recovery phrase reveal requires app re-auth when app lock is configured.
- Android screen capture protection is enabled while viewing recovery words.

## Local Data

Root Wallet stores non-sensitive settings in shared preferences:

- backup confirmation state
- app lock toggle
- biometric toggle
- theme preference
- balance privacy preference
- cached wallet snapshot metadata

Wallet snapshots are only an offline convenience. They do not include recovery
words or private keys.

## Diagnostics

Diagnostics are designed for support and debugging. They may include:

- active Esplora endpoint
- BDK network family
- wallet database path
- cache age
- wallet sync state

Diagnostics must not include:

- recovery phrase
- private keys
- raw PIN
- signed transaction secrets

## Local Wallet Deletion

The Settings screen includes a protected local wallet deletion flow. It removes
the wallet from the device and clears cached wallet state. Funds are recoverable
only with the recovery phrase.

## Network Scope

Root Wallet is currently productized around public Bitcoin testnet surfaces:

- Esplora API: `https://mempool.space/testnet/api`
- Explorer: `https://mempool.space/testnet`

Do not add unverified public backend URLs casually. Public testnet
infrastructure is less stable than mainnet infrastructure, so endpoint
additions should be manually verified before shipping.
