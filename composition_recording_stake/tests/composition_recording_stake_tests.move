// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module composition_recording_stake::composition_recording_stake_tests;

use composition_recording_stake::composition_recording_stake as crs;
use miso::composition::{Self, Composition, CompositionAdminCap};
use miso::recording::{Self, Recording, RecordingAdminCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use std::unit_test::{assert_eq, destroy};
use sui::balance;
use sui::event;

// Phantom marker types for the share/currency parameters.
public struct REC {}
public struct COMP {}
public struct USD {}

fun setup(
    ctx: &mut TxContext,
): (Composition<COMP>, CompositionAdminCap<COMP>, Recording<REC, COMP>, RecordingAdminCap<REC>) {
    let (comp, comp_cap) = composition::new_for_testing<COMP>(b"Song".to_string(), 1500, ctx);
    let (rec, rec_cap) = recording::new_for_testing<REC, COMP>(ctx);
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

#[test, expected_failure(abort_code = crs::EPoolNotForRecording, location = composition_recording_stake::composition_recording_stake)]
fun register_rejects_pool_from_other_recording() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec1, rec_cap1) = setup(ctx);
    destroy(rec_cap1);
    // A second recording of the same share type (only constructible in tests),
    // with its own pool — same type as rec1's pool but derived from rec2.
    let (mut rec2, rec_cap2) = recording::new_for_testing<REC, COMP>(ctx);
    let mut wrong_pool = pool::new<REC, USD>(rec2.uid_mut(&rec_cap2));

    // Registering rec1's stake against rec2's pool must abort (EPoolNotForRecording).
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec1, &mut wrong_pool);
    abort
}

// abort_code 1 mirrors `royalty_pool::stake::EPoolsRegistered`, which is
// package-private in `royalty_pool` and cannot be referenced from this
// package — the numeric mirror must be kept in sync with stake.move.
#[test, expected_failure(abort_code = 1, location = royalty_pool::stake)]
fun unstake_while_registered_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);

    crs::attach_stake_for_testing(&mut comp, &comp_cap, balance::create_for_testing<REC>(1000), ctx);
    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut pool);

    // Still registered → stake::destroy aborts EPoolsRegistered.
    let _coin = crs::unstake<REC, COMP>(&mut comp, &comp_cap, ctx);
    abort
}

#[test]
fun create_stake_emits_the_attached_record() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec, rec_cap) = setup(ctx);
    let comp_id = comp.id();

    // Seed the composition's balance accumulator, as the recording-creation
    // settlement of its royalty shares would have.
    balance::create_for_testing<REC>(1000).send_funds(comp_id.to_address());

    crs::create_stake<REC, COMP>(&mut comp, &comp_cap, &rec, 1000, ctx);
    assert!(crs::has_stake<REC, COMP>(&comp));

    // The event must carry the record exactly as it was written on-chain.
    let (stake_id, staked_value) = {
        let stake = crs::borrow_stake_for_testing<REC, COMP>(&comp);
        (stake.id(), stake.value())
    };
    let events = event::events_by_type<crs::StakeAttachedEvent<REC>>();
    assert_eq!(events.length(), 1);
    let (composition_id, event_stake_id, value) = crs::attached_event_fields(&events[0]);
    assert_eq!(composition_id, comp_id);
    assert_eq!(event_stake_id, stake_id);
    assert_eq!(value, 1000);
    assert_eq!(value, staked_value);

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun unstake_emits_the_detached_record() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec, rec_cap) = setup(ctx);
    let comp_id = comp.id();

    crs::attach_stake_for_testing(&mut comp, &comp_cap, balance::create_for_testing<REC>(1000), ctx);
    let stake_id = {
        let stake = crs::borrow_stake_for_testing<REC, COMP>(&comp);
        stake.id()
    };

    let principal = crs::unstake<REC, COMP>(&mut comp, &comp_cap, ctx);
    assert_eq!(principal.value(), 1000);
    assert!(!crs::has_stake<REC, COMP>(&comp));

    // The stake object is destroyed in the same call, so the event is the
    // only place the removed record survives.
    let events = event::events_by_type<crs::StakeDetachedEvent<REC>>();
    assert_eq!(events.length(), 1);
    let (composition_id, event_stake_id, value) = crs::detached_event_fields(&events[0]);
    assert_eq!(composition_id, comp_id);
    assert_eq!(event_stake_id, stake_id);
    assert_eq!(value, 1000);

    destroy(principal);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

// The `location` pin is load-bearing, not decorative: this module's flat codes
// collide with `sui::dynamic_field`'s (`EStakeExists` = 0 = EFieldAlreadyExists,
// `ENoStake` = 1 = EFieldDoesNotExist), and the dof operations on these paths
// abort with the framework code when the module assert is removed. Without the
// location pin a deleted `ENoStake`/`EStakeExists` assert would still "pass".
#[test, expected_failure(abort_code = crs::ENoStake, location = composition_recording_stake::composition_recording_stake)]
fun claim_without_stake_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);
    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));

    // No stake attached → ENoStake before any pool interaction.
    let _reward = crs::claim<REC, COMP, USD>(&mut comp, &comp_cap, &mut pool, ctx);
    abort
}

#[test, expected_failure(abort_code = crs::ENoStake, location = composition_recording_stake::composition_recording_stake)]
fun register_without_stake_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);
    // The recording's own derived pool, so the pool check passes and the
    // missing stake is what aborts.
    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));

    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut pool);
    abort
}

#[test, expected_failure(abort_code = crs::ENoStake, location = composition_recording_stake::composition_recording_stake)]
fun unregister_without_stake_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);
    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));

    crs::unregister<REC, COMP, USD>(&mut comp, &comp_cap, &mut pool);
    abort
}

#[test, expected_failure(abort_code = crs::ENoStake, location = composition_recording_stake::composition_recording_stake)]
fun unstake_without_stake_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec, rec_cap) = setup(ctx);
    destroy(rec);
    destroy(rec_cap);

    let _coin = crs::unstake<REC, COMP>(&mut comp, &comp_cap, ctx);
    abort
}

#[test, expected_failure(abort_code = crs::EStakeExists, location = composition_recording_stake::composition_recording_stake)]
fun create_stake_twice_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec, rec_cap) = setup(ctx);
    let comp_id = comp.id();
    destroy(rec_cap);

    // Seed the composition's balance accumulator, as the recording-creation
    // settlement of its royalty shares would have.
    balance::create_for_testing<REC>(1000).send_funds(comp_id.to_address());
    crs::create_stake<REC, COMP>(&mut comp, &comp_cap, &rec, 1000, ctx);

    // A second stake for the same RecordingShare type must abort.
    balance::create_for_testing<REC>(500).send_funds(comp_id.to_address());
    crs::create_stake<REC, COMP>(&mut comp, &comp_cap, &rec, 500, ctx);
    abort
}

#[test]
fun stake_is_stored_as_a_first_class_object() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec, rec_cap) = setup(ctx);

    crs::attach_stake_for_testing(&mut comp, &comp_cap, balance::create_for_testing<REC>(1000), ctx);

    // C17 regression guard: a `Stake` is a `key` object, so it must be stored
    // as a dynamic OBJECT field — resolvable by object ID through the dof
    // index. Stored as plain dynamic-field data it vanishes from object
    // indexing and this resolves to `option::none()`.
    let object_id = crs::stake_object_id_for_testing<REC, COMP>(&comp);
    assert!(object_id.is_some());
    let stake_id = crs::borrow_stake_for_testing<REC, COMP>(&comp).id();
    assert_eq!(object_id.destroy_some(), stake_id);

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun type_bound_cap_authorizes_any_composition_of_the_share_type() {
    let ctx = &mut tx_context::dummy();
    let (mut comp_a, cap_a, mut rec, rec_cap) = setup(ctx);
    // A second composition over the SAME CompositionShare type. In production
    // this pair cannot exist: `share::initialize` mints one share currency per
    // object (fixed supply, treasury consumed once), so Share type ↔ object is
    // 1:1 (MOVE-STANDARDS §5.1). `new_for_testing` skips that invariant.
    let (comp_b, cap_b) = composition::new_for_testing<COMP>(b"Other".to_string(), 1500, ctx);

    // Documented model property, NOT a missing check: the type-bound
    // `CompositionAdminCap<CompositionShare>` carries no object ID, so
    // comp_b's cap authorizes attach/register/claim on comp_a. The cap's
    // security rests entirely on the `share::initialize` 1:1 type↔object
    // invariant above — do not add a "wrong cap aborts" test here; there is
    // no id check for it to trip.
    crs::attach_stake_for_testing(&mut comp_a, &cap_b, balance::create_for_testing<REC>(1000), ctx);
    let mut pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    crs::register<REC, COMP, USD>(&mut comp_a, &cap_b, &rec, &mut pool);
    pool.deposit(balance::create_for_testing<USD>(500));
    let reward = crs::claim<REC, COMP, USD>(&mut comp_a, &cap_b, &mut pool, ctx);
    assert_eq!(reward.value(), 500);

    destroy(reward);
    destroy(pool);
    destroy(comp_a);
    destroy(cap_a);
    destroy(comp_b);
    destroy(cap_b);
    destroy(rec);
    destroy(rec_cap);
}
