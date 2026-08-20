// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Release revenue distributor for Miso.
///
/// Distributes release revenue to each track's recording royalty pool, by
/// track `split_bps`, through an obligations manifest — a hot potato that can
/// only be destroyed once every track's share has been settled to its
/// canonical destination. The type system, not the caller, is what makes the
/// destinations honest: a recording's pool address is a pure function of
/// `(recording_id, RecordingShare, Currency)` and can only ever be claimed by
/// the correctly-typed, shared `RoyaltyPool` (see `royalty_pool::pool`).
///
/// Flow: `request_revenue_distribution` wraps a revenue balance and computes one
/// `Obligation` per track. The caller then settles each track — either
/// `settle_track_revenue` (typed deposit straight into the accumulator; the pool
/// at the Share-qualified derived address is its own honesty proof) or
/// `deliver_track_revenue` (send to the derived address before the pool exists;
/// the `&Recording` witness pins the true `RecordingShare`, and the funds
/// wait, claimable only by the canonical pool). `finalize_revenue_distribution` aborts
/// unless every obligation is settled; the sub-bps remainder returns to the
/// release's own address balance.
///
/// The composition's cut is settled as recording-share ownership at recording
/// creation (see `miso::recording::new`), so a track's full share goes to its
/// recording pool — the composition earns through the recording shares it
/// stakes against that pool (see `composition_routed_stake`), and no
/// composition split happens here.
///
/// Events are fat by design (MOVE-STANDARDS §7): one
/// `ReleaseRevenueDistributedEvent` per settled track carries the full row so
/// indexers only ingest and store. A `MAX_TRACKS`-sized distribution PTB emits
/// 255 settle events + 1 summary = 256, within the per-transaction event cap.
module release_revenue_distributor::release_revenue_distributor;

use hikida::hikida;
use miso::recording::Recording;
use miso::release::{Release, ReleaseAdminCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use sui::balance::Balance;
use sui::coin::Coin;
use sui::event::emit;
use sui::transfer::Receiving;

// === Errors ===

/// The obligation at this track index is already settled.
const EAlreadySettled: u64 = 0;
/// `finalize_revenue_distribution` called while an obligation remains unsettled.
const ENotSettled: u64 = 1;
/// The supplied `Recording` is not the one this track's obligation names.
const ERecordingMismatch: u64 = 2;
/// Track index out of bounds for this manifest.
const ENoSuchTrack: u64 = 3;

// === Structs ===

/// Hot potato: no abilities. Wraps the revenue being distributed and the
/// per-track obligations; can only be destroyed by `finalize_revenue_distribution`, which
/// requires every obligation settled — so a distribution, once requested,
/// completes in full within its transaction or not at all.
public struct DistributionManifest<phantom Currency> {
    release_id: ID,
    revenue: Balance<Currency>,
    obligations: vector<Obligation>,
    total_input_value: u64,
    total_distributed_value: u64,
}

/// One track's share of the distribution. `obligations[i]` corresponds to
/// tracklist index `i`.
public struct Obligation has copy, drop, store {
    recording_id: ID,
    /// This track's cut of the total input, in currency base units.
    amount_value: u64,
    settled: bool,
}

// === Events ===

public struct ReleaseRevenueDistributedEvent<phantom Currency> has copy, drop {
    release_id: ID,
    /// Position in the release's flat, ordered tracklist. Kept in the payload
    /// because a recording may appear on more than one track, so
    /// `recording_id` alone does not identify which track paid.
    track_index: u64,
    recording_id: ID,
    recording_split_value: u64,
    /// True when the split was deposited into the pool's accumulator in this
    /// transaction (`settle_track_revenue`); false when it was delivered to the
    /// pool's derived address to await folding (`deliver_track_revenue`).
    deposited: bool,
}

public struct ReleaseRevenueDistributionSummaryEvent<phantom Currency> has copy, drop {
    release_id: ID,
    total_input_value: u64,
    total_distributed_value: u64,
    remainder_value: u64,
}

// === Public Functions ===

/// Wrap `revenue` for distribution across `release`'s tracks, computing each
/// track's cut by `split_bps` of the total. Returns the manifest hot potato;
/// the caller must settle every track and call `finalize_revenue_distribution` in the same
/// transaction. Permissionless: the caller composes the balance however it
/// likes — e.g. `coin.into_balance()` on a buyer's payment — or sources it
/// from the release's own custody via the cap-gated helpers below.
///
/// A share that floors to zero base units is born settled (it pays nothing —
/// the same zero-share skip `recording::new` uses), so dust-split tracks
/// never block destruction.
public fun request_revenue_distribution<Currency>(
    release: &Release,
    revenue: Balance<Currency>,
): DistributionManifest<Currency> {
    let total_input_value = revenue.value();
    let tracks = release.tracks();

    let obligations = vector::tabulate!(tracks.length(), |track_index| {
        let track = &tracks[track_index];
        let amount_value = track.split_bps().apply(total_input_value);
        Obligation {
            recording_id: track.recording_id(),
            amount_value,
            settled: amount_value == 0,
        }
    });

    DistributionManifest {
        release_id: release.id(),
        revenue,
        obligations,
        total_input_value,
        total_distributed_value: 0,
    }
}

/// Redeem `value` from the release's balance accumulator and wrap it for
/// distribution. Cap-gated because it pulls from the release's custody; the
/// returned manifest is then settled like any other.
public fun redeem_balance_and_request_revenue_distribution<Currency>(
    release: &mut Release,
    cap: &ReleaseAdminCap,
    value: u64,
): DistributionManifest<Currency> {
    let revenue = hikida::redeem_balance<Currency>(release.uid_mut(cap), value);
    request_revenue_distribution(release, revenue)
}

/// Receive coins sent to the release's address and wrap them for
/// distribution. Cap-gated because it pulls from the release's custody.
public fun receive_balance_and_request_revenue_distribution<Currency>(
    release: &mut Release,
    cap: &ReleaseAdminCap,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    ctx: &mut TxContext,
): DistributionManifest<Currency> {
    let coin = hikida::receive_coin<Currency>(release.uid_mut(cap), coins_to_receive, ctx);
    request_revenue_distribution(release, coin.into_balance())
}

/// Settle one track by depositing its cut straight into the recording's
/// royalty pool accumulator. No witness needed: the pool sitting at the
/// `(recording_id, RecordingShare, Currency)` derived address is itself proof
/// that it is the recording's correctly-typed, shared pool — that address
/// admits no other object. Aborts (in `pool::deposit`) if the pool has no
/// registered stakes; use `deliver_track_revenue` for that track instead and the
/// funds will wait at the pool's address.
public fun settle_track_revenue<RecordingShare, Currency>(
    self: &mut DistributionManifest<Currency>,
    track_index: u64,
    recording_pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    let release_id = self.release_id;
    let obligation = self.checkout(track_index);
    recording_pool.assert_derived_from(obligation.recording_id);

    let split = self.revenue.split(obligation.amount_value);
    self.total_distributed_value = self.total_distributed_value + obligation.amount_value;
    recording_pool.deposit(split);

    emit(ReleaseRevenueDistributedEvent<Currency> {
        release_id,
        track_index,
        recording_id: obligation.recording_id,
        recording_split_value: obligation.amount_value,
        deposited: true,
    });
}

/// Settle one track by sending its cut to the derived address of the
/// recording's royalty pool — which need not exist yet: the address admits
/// only the correctly-typed, shared pool, so the funds are committed to
/// recording-share holders from this moment and fold in permissionlessly
/// once the pool exists and a stake registers.
///
/// The `recording` witness pins `RecordingShare`: the settler cannot derive
/// with a foreign share type, because the recording named by the obligation
/// binds its true type parameters.
public fun deliver_track_revenue<RecordingShare, CompositionShare, Currency>(
    self: &mut DistributionManifest<Currency>,
    track_index: u64,
    recording: &Recording<RecordingShare, CompositionShare>,
) {
    let release_id = self.release_id;
    let obligation = self.checkout(track_index);
    assert!(recording.id() == obligation.recording_id, ERecordingMismatch);

    let split = self.revenue.split(obligation.amount_value);
    self.total_distributed_value = self.total_distributed_value + obligation.amount_value;
    split.send_funds(pool::derived_address<RecordingShare, Currency>(obligation.recording_id));

    emit(ReleaseRevenueDistributedEvent<Currency> {
        release_id,
        track_index,
        recording_id: obligation.recording_id,
        recording_split_value: obligation.amount_value,
        deposited: false,
    });
}

/// Destroy the manifest. Aborts unless every obligation is settled — the
/// completeness guarantee: revenue wrapped by `request_revenue_distribution` reaches
/// every track's canonical destination or the whole transaction fails. The
/// sub-bps remainder (splits floor; at most one base unit per track) returns
/// to the release's own address balance.
public fun finalize_revenue_distribution<Currency>(self: DistributionManifest<Currency>) {
    let DistributionManifest {
        release_id,
        revenue,
        obligations,
        total_input_value,
        total_distributed_value,
    } = self;

    obligations.do_ref!(|obligation| assert!(obligation.settled, ENotSettled));

    let remainder_value = revenue.value();
    emit(ReleaseRevenueDistributionSummaryEvent<Currency> {
        release_id,
        total_input_value,
        total_distributed_value,
        remainder_value,
    });

    if (remainder_value > 0) {
        revenue.send_funds(release_id.to_address());
    } else {
        revenue.destroy_zero();
    };
}

// === View Functions ===

public fun release_id<Currency>(self: &DistributionManifest<Currency>): ID {
    self.release_id
}

public fun obligation_fields<Currency>(
    self: &DistributionManifest<Currency>,
    track_index: u64,
): (ID, u64, bool) {
    assert!(track_index < self.obligations.length(), ENoSuchTrack);
    let obligation = &self.obligations[track_index];
    (obligation.recording_id, obligation.amount_value, obligation.settled)
}

public fun is_fully_settled<Currency>(self: &DistributionManifest<Currency>): bool {
    !self.obligations.any!(|obligation| !obligation.settled)
}

// === Private Functions ===

/// Fetch a copy of the obligation at `track_index` and mark it settled.
/// Aborts if out of bounds or already settled. The returned copy carries the
/// pre-settlement fields for the caller to act on.
fun checkout<Currency>(
    self: &mut DistributionManifest<Currency>,
    track_index: u64,
): Obligation {
    assert!(track_index < self.obligations.length(), ENoSuchTrack);
    let obligation = &mut self.obligations[track_index];
    assert!(!obligation.settled, EAlreadySettled);
    obligation.settled = true;
    *obligation
}

// === Test Functions ===

#[test_only]
public fun distributed_event_fields<Currency>(
    event: &ReleaseRevenueDistributedEvent<Currency>,
): (ID, u64, ID, u64, bool) {
    (
        event.release_id,
        event.track_index,
        event.recording_id,
        event.recording_split_value,
        event.deposited,
    )
}

#[test_only]
public fun summary_event_fields<Currency>(
    event: &ReleaseRevenueDistributionSummaryEvent<Currency>,
): (ID, u64, u64, u64) {
    (
        event.release_id,
        event.total_input_value,
        event.total_distributed_value,
        event.remainder_value,
    )
}
