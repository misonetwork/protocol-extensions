// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_revenue_distributor::release_revenue_distributor_tests;

use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use release_revenue_distributor::release_revenue_distributor as distributor;
use std::unit_test::{assert_eq, destroy};
use sui::balance;
use sui::coin::{Self, Coin};
use sui::event;
use sui::test_scenario;

// Mirrored from miso::release::EUnauthorized (private there).
const EUnauthorized: u64 = 0;
// Mirrored from hikida::hikida (both private there).
const ENoCoinsToReceive: u64 = 0;
const ENoValueToRedeem: u64 = 1;

const A: address = @0xA1;

/// Phantom currency for test balances.
public struct TEST_CURRENCY() has drop;

/// A 3-track release with 4000/3000/3000 bps splits. Returns the release,
/// its admin cap, and the per-track recording IDs (the routing targets).
fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap, vector<ID>) {
    let release_id = test_helpers::fake_id(ctx);
    let recordings = vector[
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
    ];
    let tracks = vector[
        track::new_for_testing(recordings[0], release_id, 4000),
        track::new_for_testing(recordings[1], release_id, 3000),
        track::new_for_testing(recordings[2], release_id, 3000),
    ];
    let (rel, cap) = release::new_for_testing(b"Album".to_string(), tracks, ctx);
    (rel, cap, recordings)
}

fun distributed_events(): vector<distributor::ReleaseRevenueDistributedEvent<TEST_CURRENCY>> {
    event::events_by_type<distributor::ReleaseRevenueDistributedEvent<TEST_CURRENCY>>()
}

fun summary_events(): vector<distributor::ReleaseRevenueDistributionSummaryEvent<TEST_CURRENCY>> {
    event::events_by_type<distributor::ReleaseRevenueDistributionSummaryEvent<TEST_CURRENCY>>()
}

// === distribute_revenue ===

#[test]
fun distribute_splits_by_bps_and_conserves_value() {
    let ctx = &mut tx_context::dummy();
    let (rel, cap, recordings) = mk_release(ctx);
    let release_id = rel.id();

    // 4000/3000/3000 bps on 10_001 → 4000/3000/3000, remainder 1.
    distributor::distribute_revenue(&rel, balance::create_for_testing<TEST_CURRENCY>(10_001));

    let events = distributed_events();
    assert_eq!(events.length(), 3);
    let expected_values = vector[4000u64, 3000, 3000];
    3u64.do!(|i| {
        let (event_release_id, track_index, recording_id, split_value) =
            distributor::distributed_event_fields(&events[i]);
        assert_eq!(event_release_id, release_id);
        assert_eq!(track_index, i);
        assert_eq!(recording_id, recordings[i]);
        assert_eq!(split_value, expected_values[i]);
    });

    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (summary_release_id, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(summary_release_id, release_id);
    assert_eq!(total_input, 10_001);
    assert_eq!(total_distributed, 10_000);
    assert_eq!(remainder, 1);
    // Conservation: every input unit is either distributed or remainder.
    assert_eq!(total_distributed + remainder, total_input);

    destroy(rel);
    destroy(cap);
}

#[test]
fun distribute_skips_share_that_floors_to_zero() {
    let ctx = &mut tx_context::dummy();
    let release_id = test_helpers::fake_id(ctx);
    let dust_recording = test_helpers::fake_id(ctx);
    let main_recording = test_helpers::fake_id(ctx);
    // 1 bps of input 100 floors to 0; the 9999 bps track takes 99.
    let tracks = vector[
        track::new_for_testing(dust_recording, release_id, 1),
        track::new_for_testing(main_recording, release_id, 9999),
    ];
    let (rel, cap) = release::new_for_testing(b"Album".to_string(), tracks, ctx);

    distributor::distribute_revenue(&rel, balance::create_for_testing<TEST_CURRENCY>(100));

    // The dusted track pays nothing: no split, no send, and no per-track
    // event. The only per-track event is the 9999 bps track's.
    let events = distributed_events();
    assert_eq!(events.length(), 1);
    let (_, track_index, recording_id, split_value) =
        distributor::distributed_event_fields(&events[0]);
    assert_eq!(track_index, 1);
    assert_eq!(recording_id, main_recording);
    assert_eq!(split_value, 99);

    // The dusted unit is not lost: it stays in the remainder, which returns
    // to the release.
    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 100);
    assert_eq!(total_distributed, 99);
    assert_eq!(remainder, 1);

    destroy(rel);
    destroy(cap);
}

#[test]
fun exact_splits_leave_zero_remainder() {
    let ctx = &mut tx_context::dummy();
    let (rel, cap, _) = mk_release(ctx);

    // 4000/3000/3000 bps on 10_000 consumes the input exactly, so the
    // remainder is destroyed rather than sent back to the release.
    distributor::distribute_revenue(&rel, balance::create_for_testing<TEST_CURRENCY>(10_000));

    let events = distributed_events();
    assert_eq!(events.length(), 3);

    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 10_000);
    assert_eq!(total_distributed, 10_000);
    assert_eq!(remainder, 0);

    destroy(rel);
    destroy(cap);
}

#[test]
fun duplicate_recording_pays_each_track_by_index() {
    let ctx = &mut tx_context::dummy();
    let release_id = test_helpers::fake_id(ctx);
    let recording = test_helpers::fake_id(ctx);
    // The same recording on two tracks: both sends route to the same address.
    let tracks = vector[
        track::new_for_testing(recording, release_id, 5000),
        track::new_for_testing(recording, release_id, 5000),
    ];
    let (rel, cap) = release::new_for_testing(b"Single".to_string(), tracks, ctx);

    distributor::distribute_revenue(&rel, balance::create_for_testing<TEST_CURRENCY>(1_000));

    // The two payments are told apart by `track_index` alone — the reason the
    // event payload keeps it.
    let events = distributed_events();
    assert_eq!(events.length(), 2);
    2u64.do!(|i| {
        let (_, track_index, recording_id, split_value) =
            distributor::distributed_event_fields(&events[i]);
        assert_eq!(track_index, i);
        assert_eq!(recording_id, recording);
        assert_eq!(split_value, 500);
    });

    destroy(rel);
    destroy(cap);
}

#[test]
fun zero_input_distributes_nothing() {
    let ctx = &mut tx_context::dummy();
    let (rel, cap, _) = mk_release(ctx);

    distributor::distribute_revenue(&rel, balance::create_for_testing<TEST_CURRENCY>(0));

    // Every share floors to zero: no per-track events, and the zero remainder
    // is destroyed (this path makes no funds-accumulator calls at all).
    assert_eq!(distributed_events().length(), 0);

    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 0);
    assert_eq!(total_distributed, 0);
    assert_eq!(remainder, 0);

    destroy(rel);
    destroy(cap);
}

// === redeem_and_distribute_revenue ===

#[test]
fun redeem_from_accumulator_and_distributes() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap, _) = mk_release(ctx);

    // Seed the release's balance accumulator, as prior `send_funds` payments
    // to its address would.
    balance::create_for_testing<TEST_CURRENCY>(10_001).send_funds(rel.id().to_address());

    distributor::redeem_and_distribute_revenue<TEST_CURRENCY>(&mut rel, &cap, 10_001);

    // Same economics as the balance path: 10_001 in → 4000/3000/3000 + 1.
    assert_eq!(distributed_events().length(), 3);
    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 10_001);
    assert_eq!(total_distributed, 10_000);
    assert_eq!(remainder, 1);

    destroy(rel);
    destroy(cap);
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun redeem_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel_a, _cap_a, _) = mk_release(ctx);
    let (_rel_b, cap_b, _) = mk_release(ctx);

    distributor::redeem_and_distribute_revenue<TEST_CURRENCY>(&mut rel_a, &cap_b, 1);
    abort
}

#[test, expected_failure(abort_code = ENoValueToRedeem, location = hikida::hikida)]
fun redeem_zero_value_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap, _) = mk_release(ctx);

    distributor::redeem_and_distribute_revenue<TEST_CURRENCY>(&mut rel, &cap, 0);
    abort
}

// === receive_and_distribute_revenue ===

#[test]
fun receive_coins_and_distributes() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap, _) = mk_release(ts.ctx());
    let release_address = rel.id().to_address();

    // Two coins land at the release's address (e.g. direct fan payments).
    let coin_a = coin::mint_for_testing<TEST_CURRENCY>(6_000, ts.ctx());
    let coin_b = coin::mint_for_testing<TEST_CURRENCY>(4_001, ts.ctx());
    let coin_a_id = object::id(&coin_a);
    let coin_b_id = object::id(&coin_b);
    transfer::public_transfer(coin_a, release_address);
    transfer::public_transfer(coin_b, release_address);

    ts.next_tx(A);

    let coins_to_receive = vector[
        test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_a_id),
        test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_b_id),
    ];
    distributor::receive_and_distribute_revenue(&mut rel, &cap, coins_to_receive, ts.ctx());

    // Same economics as the balance path: 10_001 in → 4000/3000/3000 + 1.
    assert_eq!(distributed_events().length(), 3);
    let summaries = summary_events();
    assert_eq!(summaries.length(), 1);
    let (_, total_input, total_distributed, remainder) =
        distributor::summary_event_fields(&summaries[0]);
    assert_eq!(total_input, 10_001);
    assert_eq!(total_distributed, 10_000);
    assert_eq!(remainder, 1);

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun receive_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel_a, _cap_a, _) = mk_release(ctx);
    let (_rel_b, cap_b, _) = mk_release(ctx);

    // The cap-gate fires before hikida ever sees the (empty) coin vector.
    distributor::receive_and_distribute_revenue<TEST_CURRENCY>(&mut rel_a, &cap_b, vector[], ctx);
    abort
}

#[test, expected_failure(abort_code = ENoCoinsToReceive, location = hikida::hikida)]
fun receive_with_no_coins_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap, _) = mk_release(ctx);

    distributor::receive_and_distribute_revenue<TEST_CURRENCY>(&mut rel, &cap, vector[], ctx);
    abort
}
