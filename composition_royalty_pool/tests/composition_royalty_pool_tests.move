// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module composition_royalty_pool::composition_royalty_pool_tests;

use composition_royalty_pool::composition_royalty_pool;
use miso::composition::{Self, Composition, CompositionAdminCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::unit_test::destroy;
use sui::balance;
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self, Scenario};

const ALICE: address = @0xA1;

public struct TEST_SHARE() has drop;
public struct TEST_CURRENCY() has drop;

// === Helpers ===

fun new_composition_fixture(
    scenario: &mut Scenario,
): (Composition<TEST_SHARE>, CompositionAdminCap<TEST_SHARE>) {
    composition::new_for_testing<TEST_SHARE>(
        b"Test Composition".to_string(),
        2_000,
        scenario.ctx(),
    )
}

fun new_stake(scenario: &mut Scenario, amount: u64): Stake<TEST_SHARE> {
    stake::new(balance::create_for_testing<TEST_SHARE>(amount), scenario.ctx())
}

// === Tests ===

#[test]
/// `initialize_pool` derives the pool address from the composition's UID.
fun test_initialize_pool() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let (mut composition, cap) = new_composition_fixture(&mut scenario);
    let composition_id = composition.id();
    let pool = composition_royalty_pool::initialize_pool<TEST_SHARE, TEST_CURRENCY>(
        &mut composition,
        &cap,
    );

    assert!(object::id_to_address(&pool.id()) == pool::derived_address<TEST_CURRENCY>(composition_id));
    pool.assert_derived_from(composition_id);

    pool.share();
    destroy(composition);
    destroy(cap);
    test_scenario::end(scenario);
}

#[test]
/// Coins sent to the composition's address are folded into the pool by the
/// admin via `receive_and_deposit`. Stake then claims the full deposit.
fun test_receive_and_deposit_full_flow() {
    let mut scenario = test_scenario::begin(ALICE);

    // Initialize composition + pool, register a stake.
    scenario.next_tx(ALICE);
    let (mut composition, cap) = new_composition_fixture(&mut scenario);
    let composition_id = composition.id();
    let pool = composition_royalty_pool::initialize_pool<TEST_SHARE, TEST_CURRENCY>(
        &mut composition,
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

    // Royalty payer sends coin to composition's address.
    scenario.next_tx(ALICE);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(1_000),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, composition_id.to_address());

    // Admin folds the coin into the pool via the distributor.
    scenario.next_tx(ALICE);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);
    composition_royalty_pool::receive_and_deposit(
        &mut composition,
        &cap,
        vector[ticket],
        &mut pool,
    );

    // Stake claims.
    let reward = pool.claim_rewards(&mut s);
    assert!(reward.value() == 1_000);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(reward);
    destroy(composition);
    destroy(cap);
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = composition_royalty_pool::EPoolNotForComposition)]
/// `receive_and_deposit` aborts when the pool was derived from a different
/// composition.
fun test_receive_aborts_for_wrong_pool() {
    let mut scenario = test_scenario::begin(ALICE);

    // Composition A with its own pool.
    scenario.next_tx(ALICE);
    let (mut a_comp, a_cap) = new_composition_fixture(&mut scenario);
    let a_pool = composition_royalty_pool::initialize_pool<TEST_SHARE, TEST_CURRENCY>(
        &mut a_comp,
        &a_cap,
    );
    let a_pool_id = a_pool.id();
    a_pool.share();

    // Composition B (no pool of its own; we'll try to fold its revenue into A's pool).
    scenario.next_tx(ALICE);
    let (mut b_comp, b_cap) = new_composition_fixture(&mut scenario);
    let b_id = b_comp.id();

    // Register a stake against A's pool so the deposit doesn't abort on
    // ENoStakedShares (we want to hit EPoolNotForComposition specifically).
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
    composition_royalty_pool::receive_and_deposit(
        &mut b_comp,
        &b_cap,
        vector[ticket],
        &mut a_pool,
    );

    // Unreached.
    test_scenario::return_shared(a_pool);
    balance::destroy_for_testing(stake::destroy(s));
    destroy(a_comp); destroy(a_cap);
    destroy(b_comp); destroy(b_cap);
    test_scenario::end(scenario);
}
