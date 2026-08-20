// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_revenue_distributor::release_revenue_distributor_tests;

use miso::recording::{Self, Recording, RecordingAdminCap};
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use release_revenue_distributor::release_revenue_distributor as distributor;
use royalty_pool::pool;
use royalty_pool::stake;
use std::unit_test::{assert_eq, destroy};
use sui::balance;
use sui::event;

// Mirrored from release_revenue_distributor (private there).
const EAlreadySettled: u64 = 0;
const ENotSettled: u64 = 1;
const ERecordingMismatch: u64 = 2;
const ENoSuchTrack: u64 = 3;
// Mirrored from royalty_pool::pool (private there).
const EPoolNotDerivedFromParent: u64 = 0;
// Mirrored from miso::release (private there).
const EUnauthorized: u64 = 0;

/// Phantom currency for test balances.
public struct TEST_CURRENCY() has drop;

/// Phantom share markers. Each recording gets its own share type (as in
/// production); EVIL_SHARE models an attacker-controlled currency.
public struct REC_A {}
public struct REC_B {}
public struct COMP {}
public struct EVIL_SHARE {}

/// Two real recordings (distinct share types) on a 6000/4000 release.
fun mk_release(
    ctx: &mut TxContext,
): (
    Release,
    ReleaseAdminCap,
    Recording<REC_A, COMP>,
    RecordingAdminCap<REC_A>,
    Recording<REC_B, COMP>,
    RecordingAdminCap<REC_B>,
) {
    let comp_id = test_helpers::fake_id(ctx);
    let (rec_a, cap_a) = recording::new_for_testing<REC_A, COMP>(comp_id, ctx);
    let (rec_b, cap_b) = recording::new_for_testing<REC_B, COMP>(comp_id, ctx);
    let release_id = test_helpers::fake_id(ctx);
    let tracks = vector[
        track::new_for_testing(comp_id, rec_a.id(), release_id, 6000),
        track::new_for_testing(comp_id, rec_b.id(), release_id, 4000),
    ];
    let (rel, rel_cap) = release::new_for_testing(b"Album".to_string(), tracks, ctx);
    (rel, rel_cap, rec_a, cap_a, rec_b, cap_b)
}

fun distributed_events(): vector<distributor::ReleaseRevenueDistributedEvent<TEST_CURRENCY>> {
    event::events_by_type<distributor::ReleaseRevenueDistributedEvent<TEST_CURRENCY>>()
}

fun summary_events(): vector<distributor::ReleaseRevenueDistributionSummaryEvent<TEST_CURRENCY>> {
    event::events_by_type<distributor::ReleaseRevenueDistributionSummaryEvent<TEST_CURRENCY>>()
}

// === request / deliver_track_revenue / destroy ===

#[test]
fun delivery_settlement_splits_and_conserves_value() {
    let ctx = &mut tx_context::dummy();
    let (rel, rel_cap, rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);
    let release_id = rel.id();

    // 6000/4000 bps on 10_001 → 6000/4000, remainder 1.
    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_001),
    );

    let (rec_id_0, amount_0, settled_0) = m.obligation_fields(0);
    assert_eq!(rec_id_0, rec_a.id());
    assert_eq!(amount_0, 6000);
    assert!(!settled_0);
    assert!(!m.is_fully_settled());

    m.deliver_track_revenue(0, &rec_a);
    m.deliver_track_revenue(1, &rec_b);
    assert!(m.is_fully_settled());
    m.finalize_revenue_distribution();

    let events = distributed_events();
    assert_eq!(events.length(), 2);
    let (event_release_id, track_index, recording_id, split_value, deposited) =
        distributor::distributed_event_fields(&events[0]);
    assert_eq!(event_release_id, release_id);
    assert_eq!(track_index, 0);
    assert_eq!(recording_id, rec_a.id());
    assert_eq!(split_value, 6000);
    assert!(!deposited);

    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 10_001);
    assert_eq!(total_distributed, 10_000);
    assert_eq!(remainder, 1);

    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

#[test]
fun delivered_funds_fold_into_pool_created_later() {
    let ctx = &mut tx_context::dummy();
    let (rel, rel_cap, mut rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);

    // Distribute BEFORE any pool exists: funds wait at the derived address.
    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.deliver_track_revenue(0, &rec_a);
    m.deliver_track_revenue(1, &rec_b);
    m.finalize_revenue_distribution();

    // A pool created afterward claims exactly the paid address; folding is
    // permissionless once a stake registers. The redeem would abort had the
    // funds not been credited there.
    let mut pool = pool::new<REC_A, TEST_CURRENCY>(rec_a.uid_mut(&cap_a));
    let mut stake = stake::new(balance::create_for_testing<REC_A>(100), ctx);
    pool.register_stake(&mut stake);
    pool.redeem_and_deposit(6_000);
    assert_eq!(pool.balance().value(), 6_000);

    destroy(stake);
    destroy(pool);
    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

// === settle_track_revenue ===

#[test]
fun pool_settlement_deposits_directly() {
    let ctx = &mut tx_context::dummy();
    let (rel, rel_cap, mut rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);

    let mut pool = pool::new<REC_A, TEST_CURRENCY>(rec_a.uid_mut(&cap_a));
    let mut stake = stake::new(balance::create_for_testing<REC_A>(100), ctx);
    pool.register_stake(&mut stake);

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.settle_track_revenue(0, &mut pool);
    m.deliver_track_revenue(1, &rec_b);
    m.finalize_revenue_distribution();

    // Track 0's 6_000 is in the accumulator immediately, no fold step.
    assert_eq!(pool.balance().value(), 6_000);
    let events = distributed_events();
    let (_, _, _, _, deposited_0) = distributor::distributed_event_fields(&events[0]);
    let (_, _, _, _, deposited_1) = distributor::distributed_event_fields(&events[1]);
    assert!(deposited_0);
    assert!(!deposited_1);

    destroy(stake);
    destroy(pool);
    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

/// A same-typed pool derived from a DIFFERENT recording is rejected: the
/// derived-address check pins the pool to this track's recording.
#[test, expected_failure(abort_code = EPoolNotDerivedFromParent, location = royalty_pool::pool)]
fun pool_settlement_into_other_recordings_pool_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _rel_cap, _rec_a, cap_a2, _rec_b, _cap_b) = mk_release(ctx);
    // A second REC_A-typed recording (only constructible in tests) with its
    // own pool — same pool type as rec_a's would be, wrong parent.
    let (mut other_rec, _other_cap) =
        recording::new_for_testing<REC_A, COMP>(test_helpers::fake_id(ctx), ctx);
    let mut wrong_pool = pool::new<REC_A, TEST_CURRENCY>(other_rec.uid_mut(&cap_a2));

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.settle_track_revenue(0, &mut wrong_pool);
    abort
}

// === Honesty by type–address coupling ===

/// A wrong-Share pool under the same recording claims a DIFFERENT address:
/// it cannot block the canonical pool, and deliveries are credited to the
/// canonical pool's address — never the wrong-Share one's. (Address-balance
/// solvency itself is not modeled by the unit-test framework, so the
/// property is pinned via the derivation arithmetic: delivery address ==
/// honest pool id != evil pool id.)
#[test]
fun wrong_share_pool_claims_a_different_unpaid_address() {
    let ctx = &mut tx_context::dummy();
    let (rel, rel_cap, mut rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);

    // The "squat": an EVIL_SHARE pool under rec_a claims fine — at the
    // (rec_a, EVIL_SHARE, TEST_CURRENCY) address nobody pays — and the
    // canonical pool is NOT blocked: both coexist under one recording.
    let evil_pool = pool::new<EVIL_SHARE, TEST_CURRENCY>(rec_a.uid_mut(&cap_a));
    let honest_pool = pool::new<REC_A, TEST_CURRENCY>(rec_a.uid_mut(&cap_a));

    // The address `deliver_track_revenue` pays is exactly the honest pool's id.
    let delivery_address = pool::derived_address<REC_A, TEST_CURRENCY>(rec_a.id());
    assert_eq!(delivery_address, honest_pool.id().to_address());
    assert!(delivery_address != evil_pool.id().to_address());

    // And the delivery itself completes against that address.
    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.deliver_track_revenue(0, &rec_a);
    m.deliver_track_revenue(1, &rec_b);
    m.finalize_revenue_distribution();

    destroy(evil_pool);
    destroy(honest_pool);
    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

// === Manifest discipline ===

#[test, expected_failure(abort_code = ENotSettled, location = distributor)]
fun destroy_with_unsettled_track_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _rel_cap, rec_a, _cap_a, _rec_b, _cap_b) = mk_release(ctx);

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.deliver_track_revenue(0, &rec_a);
    // Track 1 unsettled: destruction must abort.
    m.finalize_revenue_distribution();
    abort
}

#[test, expected_failure(abort_code = EAlreadySettled, location = distributor)]
fun settle_same_track_twice_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _rel_cap, rec_a, _cap_a, _rec_b, _cap_b) = mk_release(ctx);

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.deliver_track_revenue(0, &rec_a);
    m.deliver_track_revenue(0, &rec_a);
    abort
}

#[test, expected_failure(abort_code = ERecordingMismatch, location = distributor)]
fun settle_with_wrong_recording_witness_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _rel_cap, _rec_a, _cap_a, _rec_b, _cap_b) = mk_release(ctx);
    // A witness whose type is right but whose identity is wrong: the settler
    // cannot substitute another recording to redirect the derivation.
    let (fake_rec, _fake_cap) =
        recording::new_for_testing<REC_A, COMP>(test_helpers::fake_id(ctx), ctx);

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.deliver_track_revenue(0, &fake_rec);
    abort
}

// === Dust and zero-input ===

#[test]
fun dust_share_is_born_settled_and_remainder_returns() {
    let ctx = &mut tx_context::dummy();
    let comp_id = test_helpers::fake_id(ctx);
    let (rec_main, main_cap) = recording::new_for_testing<REC_A, COMP>(comp_id, ctx);
    let release_id = test_helpers::fake_id(ctx);
    // 1 bps of input 100 floors to 0; the 9999 bps track takes 99.
    let tracks = vector[
        track::new_for_testing(comp_id, test_helpers::fake_id(ctx), release_id, 1),
        track::new_for_testing(comp_id, rec_main.id(), release_id, 9999),
    ];
    let (mut rel, rel_cap) = release::new_for_testing(b"Album".to_string(), tracks, ctx);

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(100),
    );
    // The dusted track is already settled at request time.
    let (_, dust_amount, dust_settled) = m.obligation_fields(0);
    assert_eq!(dust_amount, 0);
    assert!(dust_settled);
    m.deliver_track_revenue(1, &rec_main);
    m.finalize_revenue_distribution();

    // Only the paying track emits; the dusted unit returns to the release's
    // accumulator — prove it by redeeming exactly 1 through the cap helper.
    assert_eq!(distributed_events().length(), 1);
    let m2 = distributor::redeem_balance_and_request_revenue_distribution<TEST_CURRENCY>(&mut rel, &rel_cap, 1);
    // 1 unit floors to zero on both tracks: born fully settled.
    assert!(m2.is_fully_settled());
    m2.finalize_revenue_distribution();

    destroy(rel);
    destroy(rel_cap);
    destroy(rec_main);
    destroy(main_cap);
}

#[test]
fun zero_input_manifest_is_born_settled() {
    let ctx = &mut tx_context::dummy();
    let (rel, rel_cap, rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);

    let m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(0),
    );
    assert!(m.is_fully_settled());
    m.finalize_revenue_distribution();

    assert_eq!(distributed_events().length(), 0);
    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 0);
    assert_eq!(total_distributed, 0);
    assert_eq!(remainder, 0);

    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

// === Cap-gated sourcing ===

#[test]
fun redeem_balance_and_request_revenue_distribution_sources_from_release_custody() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, rel_cap, rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);

    // Seed the release's balance accumulator, as prior `send_funds` payments
    // to its address would.
    balance::create_for_testing<TEST_CURRENCY>(10_000).send_funds(rel.id().to_address());

    let mut m = distributor::redeem_balance_and_request_revenue_distribution<TEST_CURRENCY>(&mut rel, &rel_cap, 10_000);
    m.deliver_track_revenue(0, &rec_a);
    m.deliver_track_revenue(1, &rec_b);
    m.finalize_revenue_distribution();

    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 10_000);
    assert_eq!(total_distributed, 10_000);
    assert_eq!(remainder, 0);

    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun redeem_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel_a, _cap_a, _r1, _rc1, _r2, _rc2) = mk_release(ctx);
    let (_rel_b, cap_b, _r3, _rc3, _r4, _rc4) = mk_release(ctx);

    let m = distributor::redeem_balance_and_request_revenue_distribution<TEST_CURRENCY>(&mut rel_a, &cap_b, 1);
    destroy(m);
    abort
}

// === View functions ===

#[test]
fun release_id_returns_the_wrapped_release() {
    let ctx = &mut tx_context::dummy();
    let (rel, rel_cap, rec_a, cap_a, rec_b, cap_b) = mk_release(ctx);
    let release_id = rel.id();

    // Zero input is born fully settled: exercise `release_id()` without
    // needing to settle any track first.
    let m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(0),
    );
    assert_eq!(m.release_id(), release_id);
    m.finalize_revenue_distribution();

    destroy(rel);
    destroy(rel_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
}

// === Out-of-bounds track index ===

#[test, expected_failure(abort_code = ENoSuchTrack, location = distributor)]
fun obligation_fields_out_of_bounds_track_index_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _rel_cap, _rec_a, _cap_a, _rec_b, _cap_b) = mk_release(ctx);

    let m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    // The release has 2 tracks (indices 0, 1); index 2 is out of bounds.
    let (_recording_id, _amount_value, _settled) = m.obligation_fields(2);
    abort
}

/// `checkout` (invoked by both settlement functions) rejects an out-of-bounds
/// track index before either the already-settled or recording-witness check
/// can trigger.
#[test, expected_failure(abort_code = ENoSuchTrack, location = distributor)]
fun deliver_track_revenue_out_of_bounds_track_index_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _rel_cap, rec_a, _cap_a, _rec_b, _cap_b) = mk_release(ctx);

    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<TEST_CURRENCY>(10_000),
    );
    m.deliver_track_revenue(2, &rec_a);
    abort
}
