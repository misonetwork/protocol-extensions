// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module composition_recording_stake::composition_recording_stake_tests;

use composition_recording_stake::composition_recording_stake as crs;
use miso::composition::{Self, Composition, CompositionAdminCap};
use miso::recording::{Self, Recording, RecordingAdminCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use sui::balance;
use std::unit_test::{assert_eq, destroy};

// Phantom marker types for the share/currency parameters.
public struct REC {}
public struct COMP {}
public struct USD {}

fun setup(
    ctx: &mut TxContext,
): (Composition<COMP>, CompositionAdminCap<COMP>, Recording<REC, COMP>, RecordingAdminCap<REC>) {
    let (comp, comp_cap) = composition::new_for_testing<COMP>(b"Song".to_string(), 1500, ctx);
    let (rec, rec_cap) = recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx);
    (comp, comp_cap, rec, rec_cap)
}

#[test]
fun unstake_round_trips_principal() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec, rec_cap) = setup(ctx);

    crs::attach_stake_for_testing(&mut comp, &comp_cap, balance::create_for_testing<REC>(1000), ctx);
    assert!(crs::has_stake<REC, COMP>(&comp));

    // Unstake with no pool registrations returns the full principal.
    let coin = crs::unstake<REC, COMP>(&mut comp, &comp_cap, ctx);
    assert_eq!(coin.value(), 1000);
    assert!(!crs::has_stake<REC, COMP>(&comp));

    destroy(coin);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun register_claim_unregister_unstake_lifecycle() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);

    crs::attach_stake_for_testing(&mut comp, &comp_cap, balance::create_for_testing<REC>(1000), ctx);

    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut pool);

    // Fund the pool; the composition is the sole staker, so it earns all of it.
    pool.deposit(balance::create_for_testing<USD>(500));

    let reward = crs::claim<REC, COMP, USD>(&mut comp, &comp_cap, &mut pool, ctx);
    assert_eq!(reward.value(), 500);

    // Rewards drained → unregister succeeds → principal is reclaimable.
    crs::unregister<REC, COMP, USD>(&mut comp, &comp_cap, &mut pool);
    let principal = crs::unstake<REC, COMP>(&mut comp, &comp_cap, ctx);
    assert_eq!(principal.value(), 1000);
    assert!(!crs::has_stake<REC, COMP>(&comp));

    destroy(reward);
    destroy(principal);
    destroy(pool);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test, expected_failure(abort_code = 2, location = composition_recording_stake::composition_recording_stake)]
fun register_rejects_pool_from_other_recording() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec1, rec_cap1) = setup(ctx);
    // A second recording of the same share type (only constructible in tests),
    // with its own pool — same type as rec1's pool but derived from rec2.
    let (mut rec2, rec_cap2) = recording::new_for_testing<REC, COMP>(b"Other".to_string(), ctx);
    let mut wrong_pool = pool::new<REC, USD>(rec2.uid_mut(&rec_cap2));

    // Registering rec1's stake against rec2's pool must abort (EPoolNotForRecording).
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec1, &mut wrong_pool);

    destroy(comp);
    destroy(comp_cap);
    destroy(rec1);
    destroy(rec_cap1);
    destroy(rec2);
    destroy(rec_cap2);
    destroy(wrong_pool);
}

#[test, expected_failure(abort_code = 1, location = royalty_pool::stake)]
fun unstake_while_registered_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);

    crs::attach_stake_for_testing(&mut comp, &comp_cap, balance::create_for_testing<REC>(1000), ctx);
    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut pool);

    // Still registered → stake::destroy aborts EPoolsRegistered.
    let coin = crs::unstake<REC, COMP>(&mut comp, &comp_cap, ctx);

    destroy(coin);
    destroy(pool);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}
