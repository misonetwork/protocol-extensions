// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module royalty_pool::royalty_pool_tests;

use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::unit_test::destroy;
use sui::balance;
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self, Scenario};

// === Test types ===

const ALICE: address = @0xA1;

public struct TEST_SHARE() has drop;
public struct TEST_CURRENCY() has drop;
public struct OTHER_CURRENCY() has drop;

// === Helpers ===

/// Create a `RoyaltyPool<TEST_SHARE, TEST_CURRENCY>` derived from a fresh
/// parent UID, share it, dispose the parent. Returns the pool's ID for
/// later lookup via `take_shared_by_id`.
fun create_pool(scenario: &mut Scenario): ID {
    scenario.next_tx(ALICE);
    let mut parent = object::new(scenario.ctx());
    let pool = pool::new<TEST_SHARE, TEST_CURRENCY>(&mut parent);
    let pool_id = pool.id();
    pool.share();
    destroy(parent);
    pool_id
}

/// Deposit `amount` base units of `Currency` into the pool.
fun send_to_pool<S, C>(scenario: &mut Scenario, pool_id: ID, amount: u64) {
    scenario.next_tx(ALICE);
    let mut pool = scenario.take_shared_by_id<RoyaltyPool<S, C>>(pool_id);
    pool.deposit(balance::create_for_testing<C>(amount));
    test_scenario::return_shared(pool);
}

fun new_stake(scenario: &mut Scenario, amount: u64): Stake<TEST_SHARE> {
    stake::new(balance::create_for_testing<TEST_SHARE>(amount), scenario.ctx())
}

fun take_pool(scenario: &Scenario, pool_id: ID): RoyaltyPool<TEST_SHARE, TEST_CURRENCY> {
    scenario.take_shared_by_id(pool_id)
}

// === Stake CRUD ===

#[test]
fun test_stake_round_trip() {
    let mut ctx = tx_context::dummy();
    let stake = stake::new(balance::create_for_testing<TEST_SHARE>(100), &mut ctx);
    assert!(stake.value() == 100);
    assert!(stake.registration_count() == 0);
    let balance = stake::destroy(stake);
    balance::destroy_for_testing(balance);
}

#[test, expected_failure(abort_code = stake::EZeroBalance)]
fun test_stake_rejects_zero_balance() {
    let mut ctx = tx_context::dummy();
    let stake = stake::new(balance::create_for_testing<TEST_SHARE>(0), &mut ctx);
    let balance = stake::destroy(stake);
    balance::destroy_for_testing(balance);
}

// === Core register → deposit → claim → unregister flow ===

#[test]
fun test_single_staker_claims_full_deposit() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    assert!(pool.staked_shares() == 100);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 1_000);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    assert!(pool.balance().value() == 1_000);
    let reward = pool.claim_rewards(&mut s);
    assert!(reward.value() == 1_000);
    assert!(pool.balance().value() == 0);

    pool.unregister_stake(&mut s);
    assert!(pool.staked_shares() == 0);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(reward);
    test_scenario::end(scenario);
}

#[test]
fun test_two_stakes_proportional_split() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut a = new_stake(&mut scenario, 100);
    let mut b = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut a);
    pool.register_stake(&mut b);
    assert!(pool.staked_shares() == 200);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 1_000);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r_a = pool.claim_rewards(&mut a);
    let r_b = pool.claim_rewards(&mut b);
    assert!(r_a.value() == 500);
    assert!(r_b.value() == 500);
    assert!(pool.balance().value() == 0);
    pool.unregister_stake(&mut a);
    pool.unregister_stake(&mut b);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(a));
    balance::destroy_for_testing(stake::destroy(b));
    balance::destroy_for_testing(r_a);
    balance::destroy_for_testing(r_b);
    test_scenario::end(scenario);
}

#[test]
fun test_unequal_stakes_proportional_split() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut a = new_stake(&mut scenario, 300);
    let mut b = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut a);
    pool.register_stake(&mut b);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 1_000);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r_a = pool.claim_rewards(&mut a);
    let r_b = pool.claim_rewards(&mut b);
    assert!(r_a.value() == 750);
    assert!(r_b.value() == 250);
    pool.unregister_stake(&mut a);
    pool.unregister_stake(&mut b);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(a));
    balance::destroy_for_testing(stake::destroy(b));
    balance::destroy_for_testing(r_a);
    balance::destroy_for_testing(r_b);
    test_scenario::end(scenario);
}

#[test]
fun test_claim_twice_second_yields_zero() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 500);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r1 = pool.claim_rewards(&mut s);
    let r2 = pool.claim_rewards(&mut s);
    assert!(r1.value() == 500);
    assert!(r2.value() == 0);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(r1);
    balance::destroy_for_testing(r2);
    test_scenario::end(scenario);
}

#[test]
fun test_claim_pays_only_delta_since_last_claim() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 500);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r1 = pool.claim_rewards(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 200);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r2 = pool.claim_rewards(&mut s);
    assert!(r1.value() == 500);
    assert!(r2.value() == 200);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(r1);
    balance::destroy_for_testing(r2);
    test_scenario::end(scenario);
}

#[test]
fun test_re_register_after_destroy_no_retroactive_earnings() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut a = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut a);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 500);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r1 = pool.claim_rewards(&mut a);
    assert!(r1.value() == 500);
    pool.unregister_stake(&mut a);
    test_scenario::return_shared(pool);

    let recovered = stake::destroy(a);
    let mut b = stake::new(recovered, scenario.ctx());

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut b);
    let r2 = pool.claim_rewards(&mut b);
    assert!(r2.value() == 0);
    pool.unregister_stake(&mut b);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(b));
    balance::destroy_for_testing(r1);
    balance::destroy_for_testing(r2);
    test_scenario::end(scenario);
}

// === Abort paths ===

#[test, expected_failure(abort_code = pool::ENoStakedShares)]
fun test_deposit_aborts_with_zero_staked_shares() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);
    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 100);
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = pool::EInvalidValue)]
fun test_deposit_aborts_with_zero_value() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 0);

    // Cleanup never reached — included to satisfy the type checker.
    balance::destroy_for_testing(stake::destroy(s));
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = pool::EAlreadyRegistered)]
fun test_register_aborts_if_already_registered() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = pool::ENotRegistered)]
fun test_claim_aborts_if_unregistered() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    let r = pool.claim_rewards(&mut s);
    balance::destroy_for_testing(r);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = pool::ENotRegistered)]
fun test_unregister_aborts_if_unregistered() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = pool::ELastClaimIndexMismatch)]
fun test_unregister_aborts_if_unclaimed_rewards_pending() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 500);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    pool.unregister_stake(&mut s); // aborts: didn't claim first
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = stake::EPoolsRegistered)]
fun test_destroy_aborts_with_active_registrations() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    let b = stake::destroy(s); // aborts
    balance::destroy_for_testing(b);
    test_scenario::end(scenario);
}

// === Multi-currency on a single stake ===

#[test]
/// A single stake registers with two pools of different currencies and
/// claims independently from each.
fun test_two_currencies_same_stake() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let mut parent = object::new(scenario.ctx());
    let pool_a = pool::new<TEST_SHARE, TEST_CURRENCY>(&mut parent);
    let pool_b = pool::new<TEST_SHARE, OTHER_CURRENCY>(&mut parent);
    let id_a = pool_a.id();
    let id_b = pool_b.id();
    pool_a.share();
    pool_b.share();
    destroy(parent);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool_a = scenario.take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(id_a);
    let mut pool_b = scenario.take_shared_by_id<RoyaltyPool<TEST_SHARE, OTHER_CURRENCY>>(id_b);
    pool_a.register_stake(&mut s);
    pool_b.register_stake(&mut s);
    assert!(s.registration_count() == 2);
    test_scenario::return_shared(pool_a);
    test_scenario::return_shared(pool_b);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, id_a, 500);
    send_to_pool<TEST_SHARE, OTHER_CURRENCY>(&mut scenario, id_b, 700);

    scenario.next_tx(ALICE);
    let mut pool_a = scenario.take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(id_a);
    let mut pool_b = scenario.take_shared_by_id<RoyaltyPool<TEST_SHARE, OTHER_CURRENCY>>(id_b);
    let r_a = pool_a.claim_rewards(&mut s);
    let r_b = pool_b.claim_rewards(&mut s);
    assert!(r_a.value() == 500);
    assert!(r_b.value() == 700);
    pool_a.unregister_stake(&mut s);
    pool_b.unregister_stake(&mut s);
    assert!(s.registration_count() == 0);
    test_scenario::return_shared(pool_a);
    test_scenario::return_shared(pool_b);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(r_a);
    balance::destroy_for_testing(r_b);
    test_scenario::end(scenario);
}

// === pending_rewards view ===

#[test]
fun test_pending_rewards_returns_zero_for_unregistered_stake() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let s = new_stake(&mut scenario, 100);
    let pool = take_pool(&scenario, pool_id);
    assert!(pool.pending_rewards(&s) == 0);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    test_scenario::end(scenario);
}

#[test]
fun test_pending_rewards_matches_subsequent_claim() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 1_234);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let pending = pool.pending_rewards(&s);
    let claimed = pool.claim_rewards(&mut s);
    assert!(pending == claimed.value());
    assert!(pending == 1_234);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(claimed);
    test_scenario::end(scenario);
}

// === Address derivation ===

#[test]
fun test_derived_address_matches_pool_address() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let mut parent = object::new(scenario.ctx());
    let parent_id = parent.to_inner();
    let pool = pool::new<TEST_SHARE, TEST_CURRENCY>(&mut parent);
    let derived = pool::derived_address<TEST_CURRENCY>(parent_id);
    assert!(derived == object::id_to_address(&pool.id()));
    pool.assert_derived_from(parent_id);
    pool.share();
    destroy(parent);

    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = pool::EPoolNotDerivedFromParent)]
fun test_assert_derived_from_aborts_for_wrong_parent() {
    let mut scenario = test_scenario::begin(ALICE);

    scenario.next_tx(ALICE);
    let mut parent = object::new(scenario.ctx());
    let other = object::new(scenario.ctx());
    let pool = pool::new<TEST_SHARE, TEST_CURRENCY>(&mut parent);
    pool.assert_derived_from(other.to_inner()); // aborts
    pool.share();
    destroy(parent);
    destroy(other);

    test_scenario::end(scenario);
}

// === Late register: no retroactive earnings ===

#[test]
fun test_late_register_no_retroactive_share() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut a = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut a);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 1_000);

    scenario.next_tx(ALICE);
    let mut b = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut b);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 200);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r_a = pool.claim_rewards(&mut a);
    let r_b = pool.claim_rewards(&mut b);
    assert!(r_a.value() == 1_100);
    assert!(r_b.value() == 100);
    pool.unregister_stake(&mut a);
    pool.unregister_stake(&mut b);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(a));
    balance::destroy_for_testing(stake::destroy(b));
    balance::destroy_for_testing(r_a);
    balance::destroy_for_testing(r_b);
    test_scenario::end(scenario);
}

// === Consumed-index advance: fractional holders preserve credit ===

#[test]
/// A small holder claiming after every sub-threshold deposit recovers their
/// full proportional share over time. Without the consumed-index advance
/// they'd lose all credit each round.
///
/// Setup: total staked = 1_000_000 (one whole share at d=6); holder A has
/// 100 base units (1/10_000th of a whole share); holder B has the rest. Each
/// 100-base-unit deposit advances cum by 1e14, yielding A a per-round reward
/// of `100 * 1e14 / 1e18 = 0.01 → 0` (truncated). Across 100 rounds, A's
/// fair share is exactly 1 base unit; with the fix, that's what they collect.
fun test_fractional_holder_credit_preserved_across_zero_claims() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut a = new_stake(&mut scenario, 100);
    let mut b = new_stake(&mut scenario, 999_900);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut a);
    pool.register_stake(&mut b);
    test_scenario::return_shared(pool);

    let mut acc_a = balance::zero<TEST_CURRENCY>();
    100u64.do!(|_| {
        send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 100);
        scenario.next_tx(ALICE);
        let mut pool = take_pool(&scenario, pool_id);
        acc_a.join(pool.claim_rewards(&mut a));
        test_scenario::return_shared(pool);
    });

    // A claimed 0 base units for 99 rounds, then 1 on round 100 — recovering
    // their full 1-base-unit fair share over the 100 small deposits.
    assert!(acc_a.value() == 1);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r_b = pool.claim_rewards(&mut b);
    assert!(r_b.value() == 9_999);
    assert!(pool.balance().value() == 0);
    pool.unregister_stake(&mut a);
    pool.unregister_stake(&mut b);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(a));
    balance::destroy_for_testing(stake::destroy(b));
    balance::destroy_for_testing(acc_a);
    balance::destroy_for_testing(r_b);
    test_scenario::end(scenario);
}

#[test]
/// Regression: a sole-staker (`staked_amount == staked_shares`) with a
/// non-evenly-divisible deposit drains the full pool over two claims via
/// the consumed-index advance, then unregisters successfully even though
/// `last_claim_index < cumulative` by 1 (sub-base-unit accumulator residue).
fun test_sole_staker_drains_indivisible_deposit_and_unregisters() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 6);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 2);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let r1 = pool.claim_rewards(&mut s);
    let r2 = pool.claim_rewards(&mut s);
    assert!(r1.value() == 1);
    assert!(r2.value() == 1);
    assert!(pool.balance().value() == 0);
    // Accumulator residue: cum = floor(2 * 1e18 / 6) = 333…333; consumed
    // across two claims = 2 * floor(1e18 / 6) = 333…332. So
    // last_claim_index < cumulative by 1, but pending_rewards == 0.
    assert!(pool.pending_rewards(&s) == 0);

    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(r1);
    balance::destroy_for_testing(r2);
    test_scenario::end(scenario);
}

// === Recovery paths: receive_and_deposit ===

#[test]
/// A `Coin<C>` transferred directly to the pool's address can be folded
/// into the accumulator via `receive_and_deposit`, recovering the funds
/// for staker distribution.
fun test_receive_and_deposit_recovers_funds_at_pool_address() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    // Royalty payer (or a confused user) transfers a coin straight to the
    // pool's address instead of going through the distributor.
    scenario.next_tx(ALICE);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(500),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, pool_id.to_address());

    // Anyone can recover by calling receive_and_deposit on the pool.
    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);
    pool.receive_and_deposit(vector[ticket]);
    assert!(pool.balance().value() == 500);

    let reward = pool.claim_rewards(&mut s);
    assert!(reward.value() == 500);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(reward);
    test_scenario::end(scenario);
}

// === cumulative_deposits ===

#[test]
fun test_cumulative_deposits_tracks_lifetime_inflows() {
    let mut scenario = test_scenario::begin(ALICE);
    let pool_id = create_pool(&mut scenario);

    scenario.next_tx(ALICE);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool = take_pool(&scenario, pool_id);
    pool.register_stake(&mut s);
    assert!(pool.cumulative_deposits() == 0);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 100);

    scenario.next_tx(ALICE);
    let pool = take_pool(&scenario, pool_id);
    assert!(pool.cumulative_deposits() == 100);
    test_scenario::return_shared(pool);

    send_to_pool<TEST_SHARE, TEST_CURRENCY>(&mut scenario, pool_id, 250);

    scenario.next_tx(ALICE);
    let mut pool = take_pool(&scenario, pool_id);
    assert!(pool.cumulative_deposits() == 350);

    // Claims do not affect cumulative_deposits.
    let r = pool.claim_rewards(&mut s);
    assert!(pool.cumulative_deposits() == 350);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(r);
    test_scenario::end(scenario);
}
