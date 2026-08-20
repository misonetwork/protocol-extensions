# `composition_routed_stake`

> Lets a composition custody and earn on the recording shares it owns, with the earnings irrevocably routed to the composition's own royalty pool.

**Attaches to:** `miso::composition::Composition<CompositionShare>`, as a shared `routed_stake::RoutedStake<RecordingShare, CompositionShare>` derived from the composition's `UID` — one routed stake per recording-share type, at a deterministic address (`routed_stake::derived_address<RecordingShare>(composition_id)`).

In the current Miso model a composition's royalty cut is expressed as ownership of recording shares: `miso::recording::new` sends the composition its royalty-% of the new recording's shares to the composition object's address balance. This extension lets the `CompositionAdminCap` holder pull those shares out of that balance and wrap them in a shared `RoutedStake`. From there the routing is trustless: `routed_stake::sweep` is permissionless and deposits claimed recording royalties straight into the composition's own `RoyaltyPool` — the admin controls *whether* the composition stakes, never *where the rewards go*.

This package is a thin authority adapter over the generic `routed_stake` library: it binds the lib's parent-`UID` credential to `CompositionAdminCap` via `composition.uid_mut(cap)`, and adds the one miso-specific check the lib cannot know — `register` pins the earning pool to the one derived from the actual `Recording`. `create_stake` and `register` take the `Recording<RecordingShare, CompositionShare>` itself, pinning `RecordingShare` to a real recording and compile-time-enforcing the composition↔recording pairing via the shared `CompositionShare` type parameter.

## Entry points

- **`composition_routed_stake::create_stake`** — cap-gated. Redeems `value` of the composition's recording shares from its address balance and wraps them in a `RoutedStake` derived from the composition. Returns the wrapper for the caller to `routed_stake::share`. Aborts (in `derived_object::claim`) if a routed stake for that share type was already claimed.
- **`composition_routed_stake::register`** — cap-gated. Registers the routed stake against the recording's `RoyaltyPool` so future deposits accrue to it. Aborts with `EPoolNotForRecording` unless the pool is derived from the given recording.
- **`composition_routed_stake::unregister`** — cap-gated. Mirror of `register`; the pool requires claimable rewards to be drained to zero first (a final `sweep`), so accrued rewards provably reach the composition's pool before the position can move.
- **`composition_routed_stake::unstake`** — cap-gated. Removes the staked position and returns the principal shares as a `Coin<RecordingShare>`. The emptied wrapper persists (its derived address is burned forever); `restake` refills it.
- **`composition_routed_stake::restake`** — cap-gated. Refills an emptied wrapper with more shares from the composition's address balance.

Sweeping needs no adapter: call **`routed_stake::sweep`** directly with the recording pool, the composition's pool, and the composition id. It is permissionless — anyone can complete the delivery of accrued royalties to composition-share holders.

## Dependencies

- **`miso`** — provides `Composition`, `CompositionAdminCap`, and `Recording`; supplies the cap-gated `uid_mut` that acts as the lib's parent credential.
- **`hikida`** — `redeem_balance` pulls the recording shares out of the composition's address balance.
- **`routed_stake`** — the generic shared-stake-with-committed-routing primitive.
- **`royalty_pool`** — `pool::RoyaltyPool` and the staking/claim mechanics underneath.

## Build & test

```sh
sui move build
sui move test
```

## History

Supersedes `composition_recording_stake`, which custodied the stake as a dynamic object field under the composition and exposed a cap-gated `claim` returning a free `Coin`. That package remains published (mainnet `0xf3ade246…`, testnet `0x43432344…`) and its unregister/unstake exit paths stay callable forever for any stakes created through it; this package is a fresh identity, not an upgrade.
