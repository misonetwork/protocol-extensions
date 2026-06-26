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
        b"Test Recording".to_string(),
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
