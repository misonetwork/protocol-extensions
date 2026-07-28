// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Lets a composition custody and earn on the recording shares it owns.
///
/// At recording creation, `miso::recording::new` settles the composition's
/// royalty as ownership: it sends the composition its royalty-% of the
/// recording's shares to the composition object's address balance. This
/// extension lets the `CompositionAdminCap` holder pull those shares out of the
/// address balance, wrap them in a `royalty_pool::stake::Stake`, and attach it
/// to the composition as a dynamic field — so the composition can register the
/// stake against the recording's `RoyaltyPool` and claim its proportional
/// royalties like any other share holder.
///
/// The stake is keyed by `ExtensionKey<RecordingShare>`, so a
/// composition holds one stake position per recording-share type. `create_stake`
/// and `register` take the `Recording<RecordingShare, CompositionShare>` itself:
/// this pins `RecordingShare` to a real recording (no fabricated share types) AND
/// compile-time-enforces that the recording is one of THIS composition (the
/// shared `CompositionShare`).
///
/// Full lifecycle: `create_stake` → `register` → `claim`* → `unregister` →
/// `unstake`. `unstake` reclaims the principal shares as a `Coin`; it is the
/// only exit for the granted shares, so it must exist before launch — the
/// protocol is immutable and a missing exit would strand the principal forever.
module composition_recording_stake::composition_recording_stake;

use hikida::hikida;
use miso::composition::{Composition, CompositionAdminCap};
use miso::recording::Recording;
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use sui::coin::Coin;
use sui::dynamic_field as df;

// === Errors ===

/// A stake for this recording-share type is already attached.
const EStakeExists: u64 = 0;
/// No stake for this recording-share type is attached.
const ENoStake: u64 = 1;
/// The pool was not derived from the recording whose shares are staked.
const EPoolNotForRecording: u64 = 2;

// === Dynamic field key ===

/// One stake position per recording-share type, attached to the composition.
public struct ExtensionKey<phantom RecordingShare>() has copy, drop, store;

// === Public Functions ===

/// Redeem `value` of the composition's recording shares from its address
/// balance, wrap them in a `Stake`, and attach it to the composition. Requires
/// the composition admin cap; the `recording` arg pins the valid share type and
/// the composition↔recording pairing.
public fun create_stake<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    _recording: &Recording<RecordingShare, CompositionShare>,
    value: u64,
    ctx: &mut TxContext,
) {
    let uid = composition.uid_mut(cap);
    assert!(!df::exists(uid, ExtensionKey<RecordingShare>()), EStakeExists);
    let balance = hikida::redeem_balance<RecordingShare>(uid, value);
    let stake = stake::new(balance, ctx);
    df::add(uid, ExtensionKey<RecordingShare>(), stake);
}

/// Register the composition's stake against a recording's royalty pool so
/// future deposits accrue to it. The `recording` arg pins the pool: `register`
/// aborts unless `pool` is the one derived from this recording — without it, a
/// stake could be pointed at another recording's same-typed pool and skim its
/// rewards.
public fun register<RecordingShare, CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    recording: &Recording<RecordingShare, CompositionShare>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    assert_pool_for_recording(pool, recording.id());
    let uid = composition.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey<RecordingShare>()), ENoStake);
    let stake: &mut Stake<RecordingShare> = df::borrow_mut(uid, ExtensionKey<RecordingShare>());
    pool.register_stake(stake);
}

/// Unregister the composition's stake from a recording's royalty pool. Mirror of
/// `register`; the pool's `unregister_stake` requires the stake's claimable
/// rewards to be drained to zero first (`claim`), and pins the pool by the
/// stake's recorded registration. Must be called for every pool the stake is
/// registered with before `unstake` can reclaim the principal.
public fun unregister<RecordingShare, CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    let uid = composition.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey<RecordingShare>()), ENoStake);
    let stake: &mut Stake<RecordingShare> = df::borrow_mut(uid, ExtensionKey<RecordingShare>());
    pool.unregister_stake(stake);
}

/// Detach the composition's stake and return its principal recording shares as a
/// `Coin` for the caller to route. The inverse of `create_stake`: it reclaims
/// the shares that were pulled from the composition's address balance. Aborts
/// (via `stake::destroy`) if the stake is still registered with any pool, so the
/// caller must `unregister` from every pool first. Without this path the staked
/// principal would be immobilized permanently — and the protocol is immutable,
/// so there would be no later remedy.
public fun unstake<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    ctx: &mut TxContext,
): Coin<RecordingShare> {
    let uid = composition.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey<RecordingShare>()), ENoStake);
    let position: Stake<RecordingShare> = df::remove(uid, ExtensionKey<RecordingShare>());
    stake::destroy(position).into_coin(ctx)
}

/// Claim the composition's accrued royalties from a recording's pool, returning
/// a `Coin` for the caller to route (e.g. to the composition owner).
public fun claim<RecordingShare, CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
    ctx: &mut TxContext,
): Coin<Currency> {
    let uid = composition.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey<RecordingShare>()), ENoStake);
    let stake: &mut Stake<RecordingShare> = df::borrow_mut(uid, ExtensionKey<RecordingShare>());
    pool.claim_rewards(stake).into_coin(ctx)
}

// === Public View Functions ===

/// Whether the composition holds a stake for the given recording-share type.
public fun has_stake<RecordingShare, CompositionShare>(
    composition: &Composition<CompositionShare>,
): bool {
    df::exists(composition.uid(), ExtensionKey<RecordingShare>())
}

// === Private Functions ===

/// Verify the pool was derived from the given recording (mirrors
/// `recording_royalty_pool::assert_pool_for_recording`). The pool address is a
/// pure function of `(recording_id, Currency)`, so this rejects a same-typed
/// pool belonging to any other recording.
fun assert_pool_for_recording<RecordingShare, Currency>(
    pool: &RoyaltyPool<RecordingShare, Currency>,
    recording_id: ID,
) {
    assert!(
        pool.id().to_address() == pool::derived_address<Currency>(recording_id),
        EPoolNotForRecording,
    );
}

// === Test Only ===

/// Attach a stake directly from a `Balance`, bypassing the funds-accumulator
/// redeem that `create_stake` performs. Lets tests exercise the register /
/// claim / unregister / unstake lifecycle without standing up an accumulator.
#[test_only]
public fun attach_stake_for_testing<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    balance: sui::balance::Balance<RecordingShare>,
    ctx: &mut TxContext,
) {
    let uid = composition.uid_mut(cap);
    assert!(!df::exists(uid, ExtensionKey<RecordingShare>()), EStakeExists);
    df::add(uid, ExtensionKey<RecordingShare>(), stake::new(balance, ctx));
}
