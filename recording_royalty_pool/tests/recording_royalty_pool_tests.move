// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_royalty_pool::recording_royalty_pool_tests;

use miso::recording::{Self, Recording, RecordingAdminCap};
use recording_royalty_pool::recording_royalty_pool;
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::unit_test::destroy;
use sui::balance;
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self, Scenario};

const ALICE: address = @0xA1;

public struct TEST_SHARE() has drop;
public struct TEST_COMP_SHARE() has drop;
public struct TEST_CURRENCY() has drop;

// === Helpers ===

fun new_recording_fixture(
    scenario: &mut Scenario,
): (Recording<TEST_SHARE, TEST_COMP_SHARE>, RecordingAdminCap<TEST_SHARE>) {
    recording::new_for_testing<TEST_SHARE, TEST_COMP_SHARE>(
        scenario.ctx(),
    )
}

fun new_stake(scenario: &mut Scenario, amount: u64): Stake<TEST_SHARE> {
    stake::new(balance::create_for_testing<TEST_SHARE>(amount), scenario.ctx())
}

// === Tests ===

#[test]
/// `initialize_pool` derives the pool address from the recording's UID.
fun test_initialize_pool() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let (mut recording, cap) = new_recording_fixture(&mut scenario);
    let recording_id = recording.id();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );

    assert!(object::id_to_address(&pool.id()) == pool::derived_address<TEST_CURRENCY>(recording_id));
    pool.assert_derived_from(recording_id);

    pool.share();
    destroy(recording);
    destroy(cap);
    test_scenario::end(scenario);
}

#[test]
/// Coins sent to the recording's address are folded into the pool by the
/// admin via `receive_and_deposit`. Stake then claims the full deposit.
fun test_receive_and_deposit_full_flow() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let (mut recording, cap) = new_recording_fixture(&mut scenario);
    let recording_id = recording.id();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );
    let pool_id = pool.id();
    pool.share();

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    scenario.next_tx(ALICE);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(1_000),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, recording_id.to_address());

    scenario.next_tx(ALICE);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);
    recording_royalty_pool::receive_and_deposit(
        &mut recording,
        &cap,
        vector[ticket],
        &mut pool,
    );

    let reward = pool.claim_rewards(&mut s);
    assert!(reward.value() == 1_000);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(reward);
    destroy(recording);
    destroy(cap);
    test_scenario::end(scenario);
}

#[test]
/// Funds accumulated on the recording's address are folded into the pool by
/// the admin via `redeem_and_deposit`. Stake then claims the full deposit.
fun test_redeem_and_deposit_full_flow() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let (mut recording, cap) = new_recording_fixture(&mut scenario);
    let recording_id = recording.id();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );
    let pool_id = pool.id();
    pool.share();

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    // Royalty payer's payment lands in the recording's funds accumulator.
    scenario.next_tx(ALICE);
    balance::create_for_testing<TEST_CURRENCY>(1_000).send_funds(recording_id.to_address());

    scenario.next_tx(ALICE);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    recording_royalty_pool::redeem_and_deposit(&mut recording, &cap, 1_000, &mut pool);

    let reward = pool.claim_rewards(&mut s);
    assert!(reward.value() == 1_000);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(reward);
    destroy(recording);
    destroy(cap);
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = recording_royalty_pool::EPoolNotForRecording)]
/// `redeem_and_deposit` aborts when the pool was derived from a different
/// recording.
fun test_redeem_aborts_for_wrong_pool() {
    let mut scenario = test_scenario::begin(ALICE);

    // Recording A with its own pool.
    scenario.next_tx(ALICE);
    let (mut a_rec, a_cap) = new_recording_fixture(&mut scenario);
    let a_pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut a_rec,
        &a_cap,
    );
    let a_pool_id = a_pool.id();
    a_pool.share();

    // Recording B (no pool of its own; we'll try to fold its revenue into A's pool).
    scenario.next_tx(ALICE);
    let (mut b_rec, b_cap) = new_recording_fixture(&mut scenario);
    let b_id = b_rec.id();

    // Register a stake against A's pool so the deposit doesn't abort on
    // ENoStakedShares (we want to hit EPoolNotForRecording specifically).
    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut a_pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(a_pool_id);
    a_pool.register_stake(&mut s);
    test_scenario::return_shared(a_pool);

    // Revenue lands in B's funds accumulator.
    scenario.next_tx(ALICE);
    balance::create_for_testing<TEST_CURRENCY>(100).send_funds(b_id.to_address());

    // Try to fold B's funds into A's pool — should abort.
    scenario.next_tx(ALICE);
    let mut a_pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(a_pool_id);
    recording_royalty_pool::redeem_and_deposit(&mut b_rec, &b_cap, 100, &mut a_pool);

    // Unreached.
    test_scenario::return_shared(a_pool);
    balance::destroy_for_testing(stake::destroy(s));
    destroy(a_rec); destroy(a_cap);
    destroy(b_rec); destroy(b_cap);
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = recording_royalty_pool::EPoolNotForRecording)]
/// `receive_and_deposit` aborts when the pool was derived from a different
/// recording.
fun test_receive_aborts_for_wrong_pool() {
    let mut scenario = test_scenario::begin(ALICE);

    // Recording A with its own pool.
    scenario.next_tx(ALICE);
    let (mut a_rec, a_cap) = new_recording_fixture(&mut scenario);
    let a_pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut a_rec,
        &a_cap,
    );
    let a_pool_id = a_pool.id();
    a_pool.share();

    // Recording B (no pool of its own; we'll try to fold its revenue into A's pool).
    scenario.next_tx(ALICE);
    let (mut b_rec, b_cap) = new_recording_fixture(&mut scenario);
    let b_id = b_rec.id();

    // Register a stake against A's pool so the deposit doesn't abort on
    // ENoStakedShares (we want to hit EPoolNotForRecording specifically).
    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut a_pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(a_pool_id);
    a_pool.register_stake(&mut s);
    test_scenario::return_shared(a_pool);

    // Send coin to B's address.
    scenario.next_tx(ALICE);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(100),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, b_id.to_address());

    // Try to fold B's coin into A's pool — should abort.
    scenario.next_tx(ALICE);
    let mut a_pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(a_pool_id);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);
    recording_royalty_pool::receive_and_deposit(
        &mut b_rec,
        &b_cap,
        vector[ticket],
        &mut a_pool,
    );

    // Unreached.
    test_scenario::return_shared(a_pool);
    balance::destroy_for_testing(stake::destroy(s));
    destroy(a_rec); destroy(a_cap);
    destroy(b_rec); destroy(b_cap);
    test_scenario::end(scenario);
}
