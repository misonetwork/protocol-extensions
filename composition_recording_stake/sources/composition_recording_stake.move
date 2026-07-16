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
/// composition holds one stake position per recording-share type. Every entry
/// point takes the `Recording<RecordingShare, CompositionShare>` itself: this
/// pins `RecordingShare` to a real recording (no fabricated share types) AND
/// compile-time-enforces that the recording is one of THIS composition (the
/// shared `CompositionShare`).
module composition_recording_stake::composition_recording_stake;

use hikida::hikida;
use miso::composition::{Composition, CompositionAdminCap};
use miso::recording::Recording;
use royalty_pool::pool::RoyaltyPool;
use royalty_pool::stake::{Self, Stake};
use sui::coin::Coin;
use sui::dynamic_field as df;

// === Errors ===

/// A stake for this recording-share type is already attached.
const EStakeExists: u64 = 0;
/// No stake for this recording-share type is attached.
const ENoStake: u64 = 1;

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
/// future deposits accrue to it.
public fun register<RecordingShare, CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    let uid = composition.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey<RecordingShare>()), ENoStake);
    let stake: &mut Stake<RecordingShare> = df::borrow_mut(uid, ExtensionKey<RecordingShare>());
    pool.register_stake(stake);
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
