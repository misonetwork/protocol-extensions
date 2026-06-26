// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Generative attribution edges for `Recording`.
///
/// One `RecordingAttribution<SourceShare, GenerativeRecordingShare>` per (source,
/// generated) pair, derived from the generated recording's UID — at most
/// one edge per pair, ever. The edge custodies a slice of the generated
/// recording's share supply wrapped as a royalty-pool `Stake`: **the
/// balance IS the attribution weight**. Per-source revenue accounting is
/// delegated entirely to the pool accumulator — no weight maps, no
/// rounding, no fan-out.
///
/// Creation is gated three ways: the generated recording's admin cap
/// (attachment consent), the source's opt-in `recording_attribution::
/// license` (it must be attached — absence is denial), and `stake::new`'s
/// non-zero balance requirement. After creation the edge is immutable and
/// its custody irrevocable: no withdraw, no re-weight, no exit functions;
/// shared so registration and routing are permissionless.
///
/// `route` claims the edge's accrued rewards from the generated
/// recording's pool and deposits them directly into the source recording's
/// own pool — typed pool-to-pool routing, permissionless end to end.
///
/// An edge accrues only from deposits made after it `register`s with the
/// generated recording's pool, so register every edge before that pool
/// receives revenue — the same operator discipline any royalty pool needs.
module recording_attribution::attribution;

use miso::recording::{Recording, RecordingAdminCap};
use recording_attribution::license;
use royalty_pool::pool::RoyaltyPool;
use royalty_pool::stake::{Self, Stake};
use sui::balance::Balance;
use sui::derived_object::{claim, derive_address};
use sui::event::emit;

// === Structs ===

public struct RecordingAttribution<phantom SourceShare, phantom GenerativeRecordingShare> has key {
    id: UID,
    /// The source recording this edge attributes revenue to.
    source_recording_id: ID,
    /// The generated recording this edge is attached to.
    generative_recording_id: ID,
    /// Custody of this edge's slice of the generated recording's shares.
    /// The balance IS the attribution weight. Never unstaked or destroyed.
    stake: Stake<GenerativeRecordingShare>,
}

/// Derivation key: at most one edge per (generated recording, source share
/// type) pair.
public struct RecordingAttributionKey<phantom SourceShare>() has copy, drop, store;

// === Events ===

public struct RecordingAttributionCreatedEvent<
    phantom SourceShare,
    phantom GenerativeRecordingShare,
> has copy, drop {
    attribution_id: ID,
    source_recording_id: ID,
    generative_recording_id: ID,
    staked_amount: u64,
}

public struct AttributionRevenueRoutedEvent<phantom Currency> has copy, drop {
    attribution_id: ID,
    source_recording_id: ID,
    value: u64,
}

// === Errors ===

/// A recording cannot attribute revenue to itself.
const ESelfAttribution: u64 = 0;
/// The source recording has no attribution license attached — attribution
/// is opt-in, so absence is denial.
const ESourceNotLicensed: u64 = 1;

// === Construction ===

/// Create an attribution edge, taking custody of `shares`. Gated by the
/// generated recording's admin cap; the source is passed by reference so
/// the edge provably points at a live `Recording` and its opt-in
/// attribution license can be checked — absence is denial.
public fun new<
    SourceShare,
    SourceCompositionShare,
    GenerativeRecordingShare,
    GenerativeCompositionShare,
>(
    cap: &RecordingAdminCap<GenerativeRecordingShare>,
    generative_recording: &mut Recording<GenerativeRecordingShare, GenerativeCompositionShare>,
    source_recording: &Recording<SourceShare, SourceCompositionShare>,
    shares: Balance<GenerativeRecordingShare>,
    ctx: &mut TxContext,
): RecordingAttribution<SourceShare, GenerativeRecordingShare> {
    let source_recording_id = source_recording.id();
    let generative_recording_id = generative_recording.id();
    assert!(source_recording_id != generative_recording_id, ESelfAttribution);
    assert!(license::is_attached(source_recording), ESourceNotLicensed);

    let staked_amount = shares.value();

    let attribution = RecordingAttribution<SourceShare, GenerativeRecordingShare> {
        id: claim(
            generative_recording.uid_mut(cap),
            RecordingAttributionKey<SourceShare>(),
        ),
        source_recording_id,
        generative_recording_id,
        stake: stake::new(shares, ctx), // aborts on zero balance
    };

    emit(RecordingAttributionCreatedEvent<SourceShare, GenerativeRecordingShare> {
        attribution_id: attribution.id(),
        source_recording_id,
        generative_recording_id,
        staked_amount,
    });

    attribution
}

/// Share the edge so registration and routing are permissionless.
public fun share<SourceShare, GenerativeRecordingShare>(
    self: RecordingAttribution<SourceShare, GenerativeRecordingShare>,
) {
    transfer::share_object(self);
}

// === Routing ===

/// Register the edge's stake with one of the generated recording's royalty
/// pools. Permissionless — the pool's derived address proves it belongs to
/// this edge's recording, so a foreign pool cannot capture (and block) the
/// stake's per-currency registration slot.
public fun register<SourceShare, GenerativeRecordingShare, Currency>(
    self: &mut RecordingAttribution<SourceShare, GenerativeRecordingShare>,
    pool: &mut RoyaltyPool<GenerativeRecordingShare, Currency>,
) {
    pool.assert_derived_from(self.generative_recording_id);
    pool.register_stake(&mut self.stake);
}

/// Claim the edge's accrued rewards from the generated recording's pool
/// and deposit them directly into the source recording's pool, where the
/// source's shareholders claim through their existing stakes.
/// Permissionless end to end. No-op when nothing has accrued.
public fun route<SourceShare, GenerativeRecordingShare, Currency>(
    self: &mut RecordingAttribution<SourceShare, GenerativeRecordingShare>,
    generative_pool: &mut RoyaltyPool<GenerativeRecordingShare, Currency>,
    source_pool: &mut RoyaltyPool<SourceShare, Currency>,
) {
    source_pool.assert_derived_from(self.source_recording_id);

    let payout = generative_pool.claim_rewards(&mut self.stake);
    let value = payout.value();
    if (value == 0) {
        payout.destroy_zero();
        return
    };

    emit(AttributionRevenueRoutedEvent<Currency> {
        attribution_id: self.id(),
        source_recording_id: self.source_recording_id,
        value,
    });

    source_pool.deposit(payout);
}

// === Public View Functions ===

public fun id<SourceShare, GenerativeRecordingShare>(
    self: &RecordingAttribution<SourceShare, GenerativeRecordingShare>,
): ID {
    self.id.to_inner()
}

public fun source_recording_id<SourceShare, GenerativeRecordingShare>(
    self: &RecordingAttribution<SourceShare, GenerativeRecordingShare>,
): ID {
    self.source_recording_id
}

public fun generative_recording_id<SourceShare, GenerativeRecordingShare>(
    self: &RecordingAttribution<SourceShare, GenerativeRecordingShare>,
): ID {
    self.generative_recording_id
}

/// The edge's custodied share balance — its attribution weight.
public fun staked_shares<SourceShare, GenerativeRecordingShare>(
    self: &RecordingAttribution<SourceShare, GenerativeRecordingShare>,
): u64 {
    self.stake.value()
}

/// Pending rewards in the given pool — lets cranks check whether `route`
/// is worth the gas.
public fun pending_rewards<SourceShare, GenerativeRecordingShare, Currency>(
    self: &RecordingAttribution<SourceShare, GenerativeRecordingShare>,
    pool: &RoyaltyPool<GenerativeRecordingShare, Currency>,
): u64 {
    pool.pending_rewards(&self.stake)
}

/// Deterministic address of the edge for a (generated recording, source
/// share type) pair. Useful for off-chain discovery and enumeration.
public fun derive_attribution_address<SourceShare>(generative_recording_id: ID): address {
    derive_address(generative_recording_id, RecordingAttributionKey<SourceShare>())
}
