# `composition_recording_stake`

> Lets a composition custody, stake, and earn royalties on the recording shares it owns.

**Attaches to:** `miso::composition::Composition<CompositionShare>`, via a dynamic object field on the composition's `UID` (accessed with `composition.uid_mut(cap)` / `composition.uid()`). The dynamic object field is keyed by `ExtensionKey<RecordingShare>`, so a composition holds one `royalty_pool::stake::Stake<RecordingShare>` position per recording-share type.

In the current Miso model a composition's royalty cut is expressed as ownership of recording shares: `miso::recording::new` sends the composition its royalty-% of the new recording's shares to the composition object's address balance. This extension lets the `CompositionAdminCap` holder pull those shares out of that balance, wrap them in a `Stake`, attach it to the composition, register it against the recording's `RoyaltyPool`, and claim accrued royalties — so the composition participates in the royalty pool like any other share holder.

Every mutating entry point takes the `Recording<RecordingShare, CompositionShare>` itself. This pins `RecordingShare` to a real recording (preventing fabricated share types) and compile-time-enforces that the recording belongs to this composition via the shared `CompositionShare` type parameter. Invariant: at most one stake per `RecordingShare` per composition — `create_stake` aborts with `EStakeExists` if one already exists, and `register`/`claim` abort with `ENoStake` if none does.

## Entry points

- **`composition_recording_stake::create_stake`** — cap-gated. Redeems `value` of the composition's recording shares from its address balance, wraps them in a `Stake`, and attaches it as a dynamic object field on the composition. Aborts if a stake for that share type already exists.
- **`composition_recording_stake::register`** — cap-gated. Registers the composition's attached stake against the recording's `RoyaltyPool` so future deposits accrue to it.
- **`composition_recording_stake::claim`** — cap-gated. Claims the stake's accrued royalties from the `RoyaltyPool` and returns a `Coin<Currency>` for the caller to route.

## Views

- **`composition_recording_stake::has_stake`** — returns whether the composition holds a stake for the given `RecordingShare` type.

## Dependencies

- **`miso`** — provides `Composition`, `CompositionAdminCap`, and `Recording`; supplies the composition `UID` access (`uid_mut`/`uid`) the stake dynamic object field is attached to.
- **`hikida`** — `redeem_balance` pulls the recording shares out of the composition's address balance.
- **`royalty_pool`** — `stake::Stake` (the staked position), `pool::RoyaltyPool`, and the `register_stake` / `claim_rewards` mechanics.

## Build & test

```sh
sui move build
sui move test
```
