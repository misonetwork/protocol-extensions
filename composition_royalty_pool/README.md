# `composition_royalty_pool`

> Cap-gated stake-and-claim royalty pool for a Miso `Composition`, in the same model as `recording_royalty_pool`.

**Attaches to:** `miso::composition::Composition<CompositionShare>`. Each entry point takes the `Composition` plus its `CompositionAdminCap<CompositionShare>` and reaches the composition's `&mut UID` through `composition.uid_mut(cap)` — the extension never mutates core fields, it only uses the cap-gated raw UID to receive and redeem balances. The `RoyaltyPool` itself lives in `royalty_pool` and is addressed by a deterministic derivation of `(composition_id, Currency)`.

Royalty payers send `Coin<Currency>` directly to the composition's object address — a stable inbox available from the composition's creation. The admin folds those funds into a `royalty_pool::pool::RoyaltyPool` keyed to the composition, either by receiving transferred coins (`receive_and_deposit`) or by redeeming from a `hikida` funds accumulator held on the composition's UID (`redeem_and_deposit`). Once deposited, stakeholders claim pro-rata against their `Stake<CompositionShare>` through `royalty_pool` directly.

Key invariants: the pool address is derived from `(composition_id, Currency)`, so `initialize_pool` can only be called once per currency (a second call aborts on an already-claimed address); and every deposit asserts `pool.id()` matches `pool::derived_address<Currency>(composition_id)` (`EPoolNotForComposition`), preventing one composition's revenue from being folded into another's pool. All three entry points require `&CompositionAdminCap`, keeping fold timing under admin control.

## Entry points

- **`composition_royalty_pool::initialize_pool`** — cap-gated; creates the composition's `RoyaltyPool<CompositionShare, Currency>` from the composition's UID and returns it (caller shares it). Aborts if a pool for that currency already exists.
- **`composition_royalty_pool::receive_and_deposit`** — cap-gated; receives `Coin<Currency>` objects sent to the composition's address and folds their balance into the pool. Asserts the pool belongs to the composition (`EPoolNotForComposition`).
- **`composition_royalty_pool::redeem_and_deposit`** — cap-gated; redeems `value` base units from the composition's `hikida` funds accumulator and folds the resulting balance into the pool. Asserts the pool belongs to the composition (`EPoolNotForComposition`).

## Dependencies

- **`miso`** — provides `Composition` / `CompositionAdminCap` and the cap-gated `uid_mut` access used to receive and redeem balances.
- **`royalty_pool`** — the `RoyaltyPool` accumulator, deterministic pool-address derivation, and stake/claim mechanics.
- **`hikida`** — funds-accumulator helpers (`receive_balance`, `redeem_balance`) for pulling coins and balances off the composition's UID.

## Build & test

```sh
sui move build
sui move test
```
