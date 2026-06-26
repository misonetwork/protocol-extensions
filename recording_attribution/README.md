# `recording_attribution`

> Opt-in generative-use licensing plus immutable per-edge attribution that routes a generated recording's revenue back to its source recordings via royalty-pool share custody.

**Attaches to:** `miso::recording::Recording`. The `license` module stores a `RecordingAttributionLicense` as a dynamic field under the recording's `UID` (writes gated by `RecordingAdminCap`, reads public). The `attribution` module creates `RecordingAttribution` edge objects whose ids are claimed as **derived objects** of the *generated* recording's `UID` (one edge per source-share type), each custodying a `royalty_pool::stake::Stake` of that recording's shares.

This extension models which recordings a generative recording was derived from, and pays them. The `license` module is the rights holder's opt-in surface: a source recording's admin publishes the generative-use scopes it grants (e.g. `train`, `generate`). Absence of a license is denial; an attached license with empty scopes is an explicit, timestamped opt-out; revoking detaches the license and blocks *new* edges but leaves existing edges routing (a license can be withdrawn, not rugged). Scope identifiers are forced canonical (1–64 bytes of lowercase ASCII `a-z`, `0-9`, `-`, `_`; max 16 per license, deduplicated) so the subset check at edge creation cannot be defeated by case or encoding variants.

The `attribution` module records one immutable `RecordingAttribution<SourceShare, GenerativeRecordingShare>` per (generated recording, source-share type) pair. The edge custodies a slice of the *generated* recording's share supply wrapped as a `Stake` — **the balance IS the attribution weight** — so per-source revenue accounting is delegated entirely to the royalty-pool accumulator (no weight maps, no rounding, no fan-out). Creation is gated three ways: the generated recording's admin cap (attachment consent), the source recording's attached license (absence is denial), and `stake::new`'s non-zero-balance requirement; it also rejects self-attribution. Once created the edge is shared and immutable — no withdraw, re-weight, or exit — so registration and routing are permissionless. `route` claims the edge's accrued rewards from the generated recording's pool and deposits them straight into the source recording's pool (typed pool-to-pool), where the source's shareholders claim through their own stakes.

## Entry points

- **`license::attach`** — cap-gated; validates and deduplicates scopes, then attaches a `RecordingAttributionLicense` to the source recording. Aborts if one is already attached (`ELicenseAlreadyAttached`), on too many scopes (`ETooManyScopes`), or on a non-canonical/empty/overlong scope (`EInvalidScope`). Empty `scopes` is a valid explicit opt-out. Emits `LicenseAttachedEvent`.
- **`license::revoke`** — cap-gated; removes the license, blocking new edges for this source. Existing edges are unaffected. Aborts if none attached (`ENoLicenseAttached`). Emits `LicenseRevokedEvent`.
- **`attribution::new`** — creates an edge taking custody of `shares` (a `Balance<GenerativeRecordingShare>`). Gated by the generated recording's admin cap; checks `source != generated` (`ESelfAttribution`) and that the source has a license attached (`ESourceNotLicensed`); `stake::new` aborts on a zero balance. Returns the unshared edge. Emits `RecordingAttributionCreatedEvent`.
- **`attribution::share`** — shares the edge object so registration and routing are permissionless.
- **`attribution::register`** — registers the edge's stake with one of the generated recording's `RoyaltyPool`s. Permissionless; asserts the pool is derived from the generated recording so a foreign pool cannot capture the registration slot.
- **`attribution::route`** — permissionless; asserts the source pool is derived from the source recording, claims the edge's accrued rewards from the generated pool, and deposits them into the source pool. No-op when nothing has accrued. Emits `AttributionRevenueRoutedEvent` when value is non-zero.

## Views

- **`license::is_attached`** — whether a license (including an explicit opt-out) is attached.
- **`license::grants`** — whether the license grants a given scope; false when no license is attached.
- **`license::grants_all`** — whether the license grants every scope in a `VecSet`; false when no license is attached.
- **`license::scopes`** — the granted scope set; aborts if no license is attached.
- **`attribution::id` / `source_recording_id` / `generative_recording_id`** — the edge's id and the two recording ids it links.
- **`attribution::staked_shares`** — the edge's custodied share balance (its attribution weight).
- **`attribution::pending_rewards`** — pending rewards for the edge's stake in a given pool (so cranks can decide whether `route` is worth the gas).
- **`attribution::derive_attribution_address`** — deterministic edge address for a (generated recording, source-share type) pair; useful for off-chain discovery.

## Dependencies

- **`miso`** — `Recording` / `RecordingAdminCap`; the core object this extension attaches to and gates on.
- **`royalty_pool`** — `RoyaltyPool` and `Stake`; share custody, per-currency reward accrual, and pool-to-pool routing.

## Build & test

```sh
sui move build
sui move test
```
