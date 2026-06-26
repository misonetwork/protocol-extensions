# `release_revenue_distributor`

> Splits a release's revenue across its tracks by each track's `split_bps` and forwards each share to that track's recording address.

**Attaches to:** `miso::release::Release`. It reads the release's discs and tracks through `Release` view methods, and the cap-gated entry points open the release's `&mut UID` via `release.uid_mut(&ReleaseAdminCap)` to pull funds out of the release's own custody (using `hikida`).

Revenue flows `Release → (per track) → Recording address`. For each track with a non-zero `split_bps`, the distributor takes that bps-fraction of the *total input value* and `send_funds`es it in full to the track's recording address (`recording_id.to_address()`). There is no separate composition split: the composition's cut is settled as recording-share ownership at recording creation (`miso::recording::new`), so a composition earns through the recording shares it owns. Any rounding remainder left after all track splits is sent back to the release's own address; a zero remainder is destroyed. Two `*Event` types are emitted: one per distributed track and one summary per call (total input, total distributed, remainder).

## Entry points

- **`release_revenue_distributor::distribute_revenue`** — permissionless (no cap). Takes a caller-supplied `Balance<Currency>` and splits/forwards it to track recordings. The composable primitive the other two entry points build on; a caller can pass any balance (e.g. `coin.into_balance()` on a buyer's payment).
- **`release_revenue_distributor::redeem_and_distribute_revenue`** — cap-gated (`ReleaseAdminCap`). Redeems `value` from the release's balance accumulator (`hikida::redeem_balance`) and distributes it.
- **`release_revenue_distributor::receive_and_distribute_revenue`** — cap-gated (`ReleaseAdminCap`). Receives coins sent to the release's address (`hikida::receive_coin` over the supplied `Receiving<Coin<Currency>>` vector) and distributes the resulting balance.

## Dependencies

- **`miso`** — provides `Release` / `ReleaseAdminCap`, the disc/track view methods, `track.split_bps()` (bps rate) and `track.recording_id()`, and the recording-share royalty model that makes a separate composition split unnecessary.
- **`hikida`** — custody helpers for the release's `UID`: `receive_coin` (claim coins sent to the release) and `redeem_balance` (withdraw from the release's balance accumulator).

## Build & test

```sh
sui move build
sui move test
```
