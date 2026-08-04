// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Release revenue distributor for Miso.
///
/// Distributes release revenue to each track's recording, by track `split_bps`.
///
/// Revenue flows: Release → (per track) → Recording address. The composition's
/// cut is settled as recording-share ownership at recording creation (see
/// `miso::recording::new`), so distribution routes a track's full share to
/// its recording — the composition earns through the recording shares it owns,
/// and no composition split happens here. From the recording address, the
/// recording revenue pool deposits into the reward pool for share holders to
/// claim.
///
/// Two revenue sources:
/// - Balance accumulator: funds accumulated on the release's address
/// - Coins: individual coin objects sent to the release's address
module release_revenue_distributor::release_revenue_distributor;

use hikida::hikida;
use miso::release::{Release, ReleaseAdminCap};
use sui::balance::Balance;
use sui::coin::Coin;
use sui::event::emit;
use sui::transfer::Receiving;

// === Events ===

public struct ReleaseRevenueDistributedEvent<phantom Currency> has copy, drop {
    release_id: ID,
    /// Position in the release's flat, ordered tracklist. Kept in the payload
    /// because a recording may appear on more than one track, so
    /// `recording_id` alone does not identify which track paid.
    track_index: u64,
    recording_id: ID,
    recording_split_value: u64,
}

public struct ReleaseRevenueDistributionSummaryEvent<phantom Currency> has copy, drop {
    release_id: ID,
    total_input_value: u64,
    total_distributed_value: u64,
    remainder_value: u64,
}

// === Public Functions ===

/// Redeem from the release's balance accumulator and distribute to tracks.
public fun redeem_and_distribute_revenue<Currency>(
    release: &mut Release,
    cap: &ReleaseAdminCap,
    value: u64,
) {
    let uid_mut = release.uid_mut(cap);
    let revenue = hikida::redeem_balance<Currency>(uid_mut, value);
    distribute_revenue(release, revenue);
}

/// Receive coins sent to the release's address and distribute to tracks.
public fun receive_and_distribute_revenue<Currency>(
    release: &mut Release,
    cap: &ReleaseAdminCap,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    ctx: &mut TxContext,
) {
    let uid_mut = release.uid_mut(cap);
    let coin = hikida::receive_coin<Currency>(uid_mut, coins_to_receive, ctx);
    distribute_revenue(release, coin.into_balance());
}

/// Split a revenue `Balance` across the release's tracks by `split_bps`; each
/// track's share goes in full to its recording's address. The composition's cut
/// is already settled as recording-share ownership at recording creation, so
/// there is no composition split here.
///
/// The composable primitive: permissionless, no admin cap. The caller composes
/// the balance however it likes — e.g. `coin.into_balance()` on a buyer's
/// payment — or uses `redeem_and_distribute_revenue` / `receive_and_distribute_revenue`
/// below, which source the balance from the release's own custody.
public fun distribute_revenue<Currency>(
    release: &Release,
    mut revenue: Balance<Currency>,
) {
    let total_input_value = revenue.value();
    let release_id = release.id();
    let tracks = release.tracks();
    let mut total_distributed_value: u64 = 0;

    tracks.length().do!(|track_index| {
        let track = &tracks[track_index];
        let track_split_bps = track.split_bps();

        if (track_split_bps.value() > 0) {
            // bps's `calc` was renamed to `apply` in the upstream bps
            // package. Same semantics: scale `amount` by the BPS rate.
            let rec_split_value = track_split_bps.apply(total_input_value);
            let rec_split_balance = revenue.split(rec_split_value);

            let recording_id = track.recording_id();

            total_distributed_value = total_distributed_value + rec_split_value;

            emit(ReleaseRevenueDistributedEvent<Currency> {
                release_id,
                track_index,
                recording_id,
                recording_split_value: rec_split_value,
            });

            rec_split_balance.send_funds(recording_id.to_address());
        };
    });

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
