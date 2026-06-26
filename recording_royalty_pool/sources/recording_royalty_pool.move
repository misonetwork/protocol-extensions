// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Cap-gated royalty-pool extension for `Recording`.
///
/// Royalty payers send `Coin<Currency>` directly to the recording's
/// address — a stable, well-known inbox available from the recording's
/// creation. The recording admin (cap holder) folds those funds into the
/// underlying `royalty_pool::pool::RoyaltyPool` via `receive_and_deposit`
/// (for direct coin transfers) or `redeem_and_deposit` (for
/// funds-accumulator balances).
///
/// All three entry points require `&RecordingAdminCap`, so timing of
/// fold operations stays under admin control.
module recording_royalty_pool::recording_royalty_pool;

use hikida::hikida;
use miso::recording::{Recording, RecordingAdminCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use sui::coin::Coin;
use sui::transfer::Receiving;

// === Errors ===

const EPoolNotForRecording: u64 = 0;

// === Public Functions ===

/// Create a royalty pool for a recording. Pool address derives from
/// `(recording_id, Currency)` — calling twice with the same Currency
/// aborts because the address is already claimed.
public fun initialize_pool<RecordingShare, CompositionShare, Currency>(
    recording: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
): RoyaltyPool<RecordingShare, Currency> {
    pool::new(recording.uid_mut(cap))
}

/// Receive `Coin<Currency>` objects sent to the recording's address and
/// fold them into the pool's accumulator.
public fun receive_and_deposit<RecordingShare, CompositionShare, Currency>(
    recording: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    coins: vector<Receiving<Coin<Currency>>>,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    assert_pool_for_recording(pool, recording.id());
    let balance = hikida::receive_balance(recording.uid_mut(cap), coins);
    pool.deposit(balance);
}

/// Redeem `value` base units from the recording's funds accumulator and
/// fold the resulting balance into the pool's accumulator.
public fun redeem_and_deposit<RecordingShare, CompositionShare, Currency>(
    recording: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    value: u64,
    pool: &mut RoyaltyPool<RecordingShare, Currency>,
) {
    assert_pool_for_recording(pool, recording.id());
    let balance = hikida::redeem_balance<Currency>(recording.uid_mut(cap), value);
    pool.deposit(balance);
}

// === Private Functions ===

/// Verify the pool was derived from the given recording. Prevents
/// accidentally folding one recording's revenue into another's pool.
fun assert_pool_for_recording<RecordingShare, Currency>(
    pool: &RoyaltyPool<RecordingShare, Currency>,
    recording_id: ID,
) {
    assert!(
        pool.id().to_address() == pool::derived_address<Currency>(recording_id),
        EPoolNotForRecording,
    );
}
