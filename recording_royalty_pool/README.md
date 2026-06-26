# `recording_royalty_pool`

> Cap-gated royalty pool that lets a recording's share-token holders stake and claim its inbound revenue pro-rata.

**Attaches to:** `miso::recording::Recording`. The single entry module reaches the recording's internal `UID` through the cap-gated `recording.uid_mut(cap)` accessor and passes it to `royalty_pool::pool::new`, which claims a derived object keyed on `(recording_id, Currency)`. There is no extra wrapper object — the pool *is* a derived child of the recording's UID.

Royalty payers send `Coin<Currency>` directly to the recording's address, a stable, well-known inbox that exists from the recording's creation. The recording admin (cap holder) folds those funds into a `RoyaltyPool<RecordingShare, Currency>`: `receive_and_deposit` for coins transferred to the address, `redeem_and_deposit` for value held in the recording's `hikida` funds accumulator. Holders of the recording's `RecordingShare` token register a `royalty_pool::stake::Stake` against the pool and claim deposits pro-rata to staked shares.

Key invariants: the pool address is fully determined by `(recording_id, Currency)`, so `initialize_pool` can be called at most once per currency (a second call aborts on the already-claimed derived address). Every deposit path calls `assert_pool_for_recording`, which recomputes `pool::derived_address<Currency>(recording_id)` and aborts with `EPoolNotForRecording` if the supplied pool was not derived from this recording — guarding against folding one recording's revenue into another's pool. All three public functions require `&RecordingAdminCap`, so the timing of every fold stays under admin control; staking and claiming themselves are permissionless and handled by the `royalty_pool` dependency.

## Entry points

- **`recording_royalty_pool::initialize_pool`** — cap-gated; derives and returns a `RoyaltyPool<RecordingShare, Currency>` from the recording's UID. The returned pool is unshared; the caller typically calls `pool::share` on it.
- **`recording_royalty_pool::receive_and_deposit`** — cap-gated; receives a `vector<Receiving<Coin<Currency>>>` sent to the recording's address (via `hikida::receive_balance`) and folds the combined balance into the pool with `pool.deposit`. Asserts the pool belongs to the recording.
- **`recording_royalty_pool::redeem_and_deposit`** — cap-gated; redeems `value` base units from the recording's `hikida` funds accumulator and folds the resulting balance into the pool. Asserts the pool belongs to the recording.

Staking, claiming, and sharing are performed directly against the returned/shared pool using the `royalty_pool` package (`stake::new`, `pool::register_stake`, `pool::claim_rewards`, `pool::unregister_stake`, `pool::share`).

## Dependencies

- **`miso`** — provides `Recording`, `RecordingAdminCap`, and the cap-gated `uid_mut` accessor this extension folds funds through.
- **`royalty_pool`** — the underlying `RoyaltyPool` accumulator: derived-address construction, deposit, and pro-rata stake/claim mechanics.
- **`hikida`** — pulls balances out of the recording's UID, both received `Coin` transfers (`receive_balance`) and the funds accumulator (`redeem_balance`).

## Build & test

```sh
sui move build
sui move test
```
