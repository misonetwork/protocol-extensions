// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end scenario for this package's full use case, run under
/// `sui::test_scenario`: real transaction boundaries, distinct senders, and
/// shared pools accessed via `take_shared` — exactly as client PTBs compose
/// distribution in production.
///
/// Scope: release revenue in, recording-share holders paid out —
///
///   request_revenue_distribution                (permissionless)
///     → settle_track_revenue / deliver_track_revenue
///     → finalize_revenue_distribution
///     → recording pools → recording stakers claim
///
/// The downstream composition leg (sweep → composition pool) is covered by
/// `composition_routed_stake`'s own e2e suite; the recording pool deposit is
/// the shared interface between the two.
///
/// Caveat: the unit-test framework's address-balance accumulator is
/// permissive (redeeming from an empty address succeeds), so delivery-mode
/// solvency is not provable here — amounts are pinned through the accumulator
/// math instead, and true address-balance semantics should be confirmed once
/// on localnet.
#[test_only]
module release_revenue_distributor::distribution_e2e_tests;

use miso::composition::{Self, Composition, CompositionAdminCap};
use miso::recording::{Self, Recording, RecordingAdminCap};
use miso::release;
use miso::test_helpers;
use miso::track;
use recording_royalty_pool::recording_royalty_pool;
use release_revenue_distributor::release_revenue_distributor as distributor;
use royalty_pool::pool::RoyaltyPool;
use royalty_pool::stake;
use std::unit_test::{assert_eq, destroy};
use sui::balance;
use sui::coin::{Self, Coin};
use sui::test_scenario;

// Phantom marker types.
public struct REC_A {}
public struct REC_B {}
public struct COMP {}
public struct USD {}

// Actors. ADMIN performs the cap-gated setup; PAYER and STRANGER own nothing
// and prove the permissionless legs with different senders.
const ADMIN: address = @0xAD;
const PAYER: address = @0xFA;
const STRANGER: address = @0x51;

/// A composition and a recording of it, as core would create them.
fun composition_and_recording(
    ctx: &mut TxContext,
): (Composition<COMP>, CompositionAdminCap<COMP>, Recording<REC_A, COMP>, RecordingAdminCap<REC_A>) {
    let (comp, comp_cap) = composition::new_for_testing<COMP>(b"Song".to_string(), 2000, ctx);
    let (rec, rec_cap) = recording::new_for_testing<REC_A, COMP>(comp.id(), ctx);
    (comp, comp_cap, rec, rec_cap)
}

/// Mixed-mode distribution over a two-recording release: track 0 settles into
/// an existing shared, staked pool; track 1 is delivered before its pool
/// exists and folded in afterward. The fold and claim happen transactions
/// later, against a pool created only after the money was already committed.
#[test]
fun mixed_mode_distribution_across_two_recordings() {
    let mut ts = test_scenario::begin(ADMIN);

    // --- Tx 1 (ADMIN): only rec_a's pool exists at distribution time ---
    let (comp, comp_cap, mut rec_a, cap_a) = composition_and_recording(ts.ctx());
    let (mut rec_b, cap_b) = recording::new_for_testing<REC_B, COMP>(comp.id(), ts.ctx());
    let mut pool_a =
        recording_royalty_pool::initialize_pool<REC_A, COMP, USD>(&mut rec_a, &cap_a);
    let mut stake_a = stake::new(balance::create_for_testing<REC_A>(1000), ts.ctx());
    pool_a.register_stake(&mut stake_a);
    pool_a.share();

    // --- Tx 2 (PAYER, owns nothing): one manifest, both settlement modes ---
    ts.next_tx(PAYER);
    let release_id = test_helpers::fake_id(ts.ctx());
    let tracks = vector[
        track::new_for_testing(comp.id(), rec_a.id(), release_id, 6000),
        track::new_for_testing(comp.id(), rec_b.id(), release_id, 4000),
    ];
    let (rel, rel_cap) = release::new_for_testing(b"EP".to_string(), tracks, ts.ctx());
    let mut pool_a = ts.take_shared<RoyaltyPool<REC_A, USD>>();
    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<USD>(1_000_000),
    );
    m.settle_track_revenue(0, &mut pool_a);
    m.deliver_track_revenue(1, &rec_b);
    m.finalize_revenue_distribution();
    test_scenario::return_shared(pool_a);

    // --- Tx 3 (ADMIN): rec_b's pool created after the money moved ---
    ts.next_tx(ADMIN);
    let mut pool_b =
        recording_royalty_pool::initialize_pool<REC_B, COMP, USD>(&mut rec_b, &cap_b);
    let mut stake_b = stake::new(balance::create_for_testing<REC_B>(500), ts.ctx());
    pool_b.register_stake(&mut stake_b);
    pool_b.share();

    // --- Tx 4 (STRANGER): folding the waiting delivery is permissionless ---
    ts.next_tx(STRANGER);
    let mut pool_b = ts.take_shared<RoyaltyPool<REC_B, USD>>();
    pool_b.redeem_and_deposit(400_000);
    assert_eq!(pool_b.balance().value(), 400_000);
    test_scenario::return_shared(pool_b);

    // --- Tx 5 (ADMIN): claims across both pools sum to the input ---
    ts.next_tx(ADMIN);
    let mut pool_a = ts.take_shared<RoyaltyPool<REC_A, USD>>();
    let mut pool_b = ts.take_shared<RoyaltyPool<REC_B, USD>>();
    let reward_a = pool_a.claim_rewards(&mut stake_a);
    let reward_b = pool_b.claim_rewards(&mut stake_b);
    assert_eq!(reward_a.value(), 600_000);
    assert_eq!(reward_b.value(), 400_000);
    assert_eq!(reward_a.value() + reward_b.value(), 1_000_000);
    test_scenario::return_shared(pool_a);
    test_scenario::return_shared(pool_b);

    destroy(reward_a);
    destroy(reward_b);
    destroy(stake_a);
    destroy(stake_b);
    destroy(rel);
    destroy(rel_cap);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec_a);
    destroy(cap_a);
    destroy(rec_b);
    destroy(cap_b);
    ts.end();
}

/// `receive_balance_and_request_revenue_distribution` is the third way to
/// source revenue (alongside permissionless `request_revenue_distribution`
/// and cap-gated `redeem_balance_and_request_revenue_distribution`): a coin
/// paid directly to the release's stable inbox address, pulled in by the
/// cap holder via a `Receiving` ticket across a real transaction boundary.
#[test]
fun receive_balance_and_request_revenue_distribution_pulls_a_paid_coin() {
    let mut ts = test_scenario::begin(ADMIN);

    // --- Tx 1 (ADMIN): a one-track release over rec_a ---
    let (comp, comp_cap, rec_a, cap_a) = composition_and_recording(ts.ctx());
    let release_id = test_helpers::fake_id(ts.ctx());
    let tracks = vector[track::new_for_testing(comp.id(), rec_a.id(), release_id, 10_000)];
    let (mut rel, rel_cap) = release::new_for_testing(b"Single".to_string(), tracks, ts.ctx());
    let rel_address = rel.id().to_address();

    // --- Tx 2 (PAYER, owns nothing): pays the release's address directly ---
    ts.next_tx(PAYER);
    let coin = coin::from_balance(balance::create_for_testing<USD>(500_000), ts.ctx());
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, rel_address);

    // --- Tx 3 (ADMIN): pulls the paid coin via the cap-gated receive path ---
    ts.next_tx(ADMIN);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<USD>>(coin_id);
    let mut m = distributor::receive_balance_and_request_revenue_distribution<USD>(
        &mut rel,
        &rel_cap,
        vector[ticket],
        ts.ctx(),
    );
    assert_eq!(m.release_id(), rel.id());
    m.deliver_track_revenue(0, &rec_a);
    m.finalize_revenue_distribution();

    destroy(rel);
    destroy(rel_cap);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec_a);
    destroy(cap_a);
    ts.end();
}
