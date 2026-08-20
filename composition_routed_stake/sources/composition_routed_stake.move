// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Lets a composition custody and earn on the recording shares it owns, with
/// the earnings irrevocably routed to the composition's own royalty pool.
///
/// At recording creation, `miso::recording::new` settles the composition's
/// royalty as ownership: it sends the composition its royalty-% of the
/// recording's shares to the composition object's address balance. This
/// extension lets the `CompositionAdminCap` holder pull those shares out of
/// the address balance and wrap them in a shared
/// `routed_stake::RoutedStake<RecordingShare, CompositionShare>` derived from
/// the composition. From there the routing is trustless: `routed_stake::sweep`
/// is permissionless and deposits claimed recording royalties straight into
/// the composition's own `RoyaltyPool` — the admin controls *whether* the
/// composition stakes, never *where the rewards go*.
///
/// This module is a thin authority adapter: it binds the lib's parent-UID
/// credential to `CompositionAdminCap` via `composition.uid_mut(cap)`, and
/// adds the one miso-specific check the lib cannot know — `register` pins the
/// earning pool to the one derived from the actual `Recording`. Sweeping needs
/// no adapter; call `routed_stake::sweep` directly with the composition's id.
///
/// `create_stake` and `register` take the
/// `Recording<RecordingShare, CompositionShare>` itself: this pins
/// `RecordingShare` to a real recording (no fabricated share types) AND
/// compile-time-enforces that the recording is one of THIS composition (the
/// shared `CompositionShare`).
///
/// Full lifecycle: `create_stake` (then `routed_stake::share`) → `register` →
/// `sweep`* (permissionless, in the lib) → `unregister` → `unstake` →
/// optionally `restake`. `unstake` reclaims the principal shares as a `Coin`;
/// it is the only exit for the granted shares, so it must exist before launch
/// — the protocol is immutable and a missing exit would strand the principal
/// forever. The emptied wrapper persists (its derived address is burned
/// forever) and `restake` refills it.
module composition_routed_stake::composition_routed_stake;

use hikida::hikida;
use miso::composition::{Composition, CompositionAdminCap};
use miso::recording::Recording;
use routed_stake::routed_stake::{Self, RoutedStake};
use royalty_pool::pool::{Self, RoyaltyPool};
use sui::coin::Coin;

// === Errors ===

/// The pool was not derived from the recording whose shares are staked.
const EPoolNotForRecording: u64 = 0;

// === Public Functions ===

/// Redeem `value` of the composition's recording shares from its address
/// balance and wrap them in a `RoutedStake` derived from the composition.
/// Returns the wrapper for the caller to `routed_stake::share`. Requires the
/// composition admin cap; the `recording` arg pins the valid share type and
/// the composition↔recording pairing. Aborts (in `derived_object::claim`) if
/// the composition already claimed a routed stake for this share type.
public fun create_stake<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    _recording: &Recording<RecordingShare, CompositionShare>,
    value: u64,
    ctx: &mut TxContext,
): RoutedStake<RecordingShare, CompositionShare> {
    let uid = composition.uid_mut(cap);
    let balance = hikida::redeem_balance<RecordingShare>(uid, value);
    routed_stake::new(uid, balance, ctx)
}

/// Register the composition's routed stake against a recording's royalty pool
/// so future deposits accrue to it. The `recording` arg pins the pool:
/// `register` aborts unless `pool` is the one derived from this recording —
/// without it, the stake could be pointed at another recording's same-typed
/// pool and skim its rewards.
public fun register<RecordingShare, CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    recording: &Recording<RecordingShare, CompositionShare>,
    routed: &mut RoutedStake<RecordingShare, CompositionShare>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    assert_pool_for_recording(pool, recording.id());
    routed.register(composition.uid_mut(cap), pool);
}

/// Unregister the composition's routed stake from a recording's royalty pool.
/// Mirror of `register`; the pool requires claimable rewards to be drained to
/// zero first — i.e. a final `routed_stake::sweep` — so accrued rewards
/// provably reach the composition's pool before the position can move. Must
/// be called for every pool the stake is registered with before `unstake`.
public fun unregister<RecordingShare, CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    routed: &mut RoutedStake<RecordingShare, CompositionShare>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    routed.unregister(composition.uid_mut(cap), pool);
}

/// Remove the staked position and return its principal recording shares as a
/// `Coin` for the caller to route. The inverse of `create_stake`. Aborts (via
/// `stake::destroy`) if the stake is still registered with any pool. The
/// emptied wrapper persists; `restake` refills it.
public fun unstake<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    routed: &mut RoutedStake<RecordingShare, CompositionShare>,
    ctx: &mut TxContext,
): Coin<RecordingShare> {
    routed.unstake(composition.uid_mut(cap)).into_coin(ctx)
}

/// Refill an emptied wrapper with `value` more recording shares from the
/// composition's address balance. Aborts if a position is already present.
public fun restake<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    routed: &mut RoutedStake<RecordingShare, CompositionShare>,
    value: u64,
    ctx: &mut TxContext,
) {
    let uid = composition.uid_mut(cap);
    let balance = hikida::redeem_balance<RecordingShare>(uid, value);
    routed.restake(uid, balance, ctx);
}

// === Private Functions ===

/// Verify the pool was derived from the given recording (mirrors
/// `recording_royalty_pool::assert_pool_for_recording`). The pool address is a
/// pure function of `(recording_id, RecordingShare, Currency)`, so this
/// rejects a same-typed
/// pool belonging to any other recording.
fun assert_pool_for_recording<RecordingShare, Currency>(
    pool: &RoyaltyPool<RecordingShare, Currency>,
    recording_id: ID,
) {
    assert!(
        pool.id().to_address() == pool::derived_address<RecordingShare, Currency>(recording_id),
        EPoolNotForRecording,
    );
}
