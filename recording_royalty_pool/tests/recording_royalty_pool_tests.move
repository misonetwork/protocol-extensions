// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end tests for this package's full use-case scope, run under
/// `sui::test_scenario`: real transaction boundaries, shared objects taken
/// via `take_shared`/`return_shared`, and distinct senders proving who is
/// authorized to do what. Every public function in this package is
/// cap-gated ownership mechanics over a `Recording`, so scenario mechanics
/// are the right default throughout — there is no pure-math/`dummy()`-style
/// carve-out here.
///
/// Actors: ADMIN holds the `RecordingAdminCap` and performs every cap-gated
/// fold; PAYER owns nothing and only ever sends currency to a recording's
/// address, modeling a royalty payer; STRANGER is a permissionless
/// share-token staker/claimer, and doubles as the admin of a second,
/// unrelated recording in the wrong-pool adversarial tests.
///
/// Caveat: the unit-test `hikida` address-balance accumulator is
/// permissive — `hikida::redeem_balance` from an address that was never
/// sent anything still succeeds (it mints on demand in the test harness).
/// Never treat a successful `redeem_and_deposit` as proof that funds were
/// actually delivered to the recording's address; pin delivery instead via
/// `pool::derived_address` arithmetic (the wrong-pool tests) or via direct
/// `Coin`/`Balance` transfer with `object::id` tracking through a
/// `Receiving` ticket (the `receive_and_deposit` tests).
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

const ADMIN: address = @0xAD;
const PAYER: address = @0xFA;
const STRANGER: address = @0x51;

public struct TEST_SHARE() has drop;
public struct TEST_COMP_SHARE() has drop;
public struct TEST_CURRENCY() has drop;

// === Helpers ===

fun new_recording_fixture(
    scenario: &mut Scenario,
): (Recording<TEST_SHARE, TEST_COMP_SHARE>, RecordingAdminCap<TEST_SHARE>) {
    recording::new_for_testing<TEST_SHARE, TEST_COMP_SHARE>(
        object::id_from_address(@0xC0),
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
    let mut scenario = test_scenario::begin(ADMIN);

    scenario.next_tx(ADMIN);
    let (mut recording, cap) = new_recording_fixture(&mut scenario);
    let recording_id = recording.id();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );

    assert!(object::id_to_address(&pool.id()) == pool::derived_address<TEST_SHARE, TEST_CURRENCY>(recording_id));
    pool.assert_derived_from(recording_id);

    pool.share();
    destroy(recording);
    destroy(cap);
    test_scenario::end(scenario);
}

#[test]
/// Coins sent to the recording's address by a payer who owns nothing else
/// are folded into the pool by the admin via `receive_and_deposit`. A
/// distinct staker then claims the full deposit.
fun test_receive_and_deposit_full_flow() {
    let mut scenario = test_scenario::begin(ADMIN);

    scenario.next_tx(ADMIN);
    let (mut recording, cap) = new_recording_fixture(&mut scenario);
    let recording_id = recording.id();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );
    let pool_id = pool.id();
    pool.share();

    // Tx 2 (STRANGER): a share-token holder registers a stake — permissionless,
    // no cap required.
    scenario.next_tx(STRANGER);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    // Tx 3 (PAYER, owns nothing): sends a royalty coin to the recording's
    // stable inbox address.
    scenario.next_tx(PAYER);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(1_000),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, recording_id.to_address());

    // Tx 4 (ADMIN): folds the coin into the pool.
    scenario.next_tx(ADMIN);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);
    recording_royalty_pool::receive_and_deposit(
        &mut recording,
        &cap,
        vector[ticket],
        &mut pool,
    );
    assert!(pool.balance().value() == 1_000);
    test_scenario::return_shared(pool);

    // Tx 5 (STRANGER): claims the pro-rata reward.
    scenario.next_tx(STRANGER);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
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
/// Funds accumulated on the recording's address (by a payer who owns
/// nothing else) are folded into the pool by the admin via
/// `redeem_and_deposit`. A distinct staker then claims the full deposit.
///
/// NOTE: `redeem_and_deposit` success alone does not prove delivery — see
/// the module-level caveat about `hikida::redeem_balance`'s permissive test
/// harness. The exact-amount assertion here relies on the payer having
/// actually sent 1_000 via `send_funds` in tx 3, not on the redeem call
/// succeeding.
fun test_redeem_and_deposit_full_flow() {
    let mut scenario = test_scenario::begin(ADMIN);

    scenario.next_tx(ADMIN);
    let (mut recording, cap) = new_recording_fixture(&mut scenario);
    let recording_id = recording.id();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );
    let pool_id = pool.id();
    pool.share();

    // Tx 2 (STRANGER): a share-token holder registers a stake.
    scenario.next_tx(STRANGER);
    let mut s = new_stake(&mut scenario, 100);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    // Tx 3 (PAYER, owns nothing): payment lands in the recording's funds
    // accumulator.
    scenario.next_tx(PAYER);
    balance::create_for_testing<TEST_CURRENCY>(1_000).send_funds(recording_id.to_address());

    // Tx 4 (ADMIN): folds the accumulated funds into the pool.
    scenario.next_tx(ADMIN);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    recording_royalty_pool::redeem_and_deposit(&mut recording, &cap, 1_000, &mut pool);
    assert!(pool.balance().value() == 1_000);
    test_scenario::return_shared(pool);

    // Tx 5 (STRANGER): claims the pro-rata reward.
    scenario.next_tx(STRANGER);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
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
/// Production shape: the recording is PUBLISHED AND SHARED before any pool
/// operation occurs, and every fold happens against the object retrieved
/// fresh via `take_shared` in a later transaction — proving the cap-gated
/// entry points work against the real on-chain lifecycle (per `uid_mut`'s
/// doc, they work in any lifecycle state), not just a bare owned fixture
/// that is never actually shared.
fun test_receive_and_deposit_against_published_recording() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Tx 1 (ADMIN): create and publish the recording — this shares it.
    scenario.next_tx(ADMIN);
    let (rec, cap) = new_recording_fixture(&mut scenario);
    let recording_id = rec.id();
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rec.publish(&cap, &clock); // shares the recording
    clock.destroy_for_testing();

    // Tx 2 (ADMIN): take the shared recording, initialize and share the pool.
    scenario.next_tx(ADMIN);
    let mut recording = scenario.take_shared<Recording<TEST_SHARE, TEST_COMP_SHARE>>();
    let pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut recording,
        &cap,
    );
    let pool_id = pool.id();
    assert!(object::id_to_address(&pool_id) == pool::derived_address<TEST_SHARE, TEST_CURRENCY>(recording_id));
    pool.share();
    test_scenario::return_shared(recording);

    // Tx 3 (STRANGER): a share-token holder registers a stake against the
    // shared pool — permissionless.
    scenario.next_tx(STRANGER);
    let mut s = new_stake(&mut scenario, 250);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    pool.register_stake(&mut s);
    test_scenario::return_shared(pool);

    // Tx 4 (PAYER, owns nothing): sends a royalty coin to the recording's
    // stable inbox address.
    scenario.next_tx(PAYER);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(2_500),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, recording_id.to_address());

    // Tx 5 (ADMIN): re-take the shared recording and pool, fold the coin in.
    scenario.next_tx(ADMIN);
    let mut recording = scenario.take_shared<Recording<TEST_SHARE, TEST_COMP_SHARE>>();
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    let ticket = test_scenario::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);
    recording_royalty_pool::receive_and_deposit(
        &mut recording,
        &cap,
        vector[ticket],
        &mut pool,
    );
    assert!(pool.balance().value() == 2_500);
    test_scenario::return_shared(recording);
    test_scenario::return_shared(pool);

    // Tx 6 (STRANGER): claims the pro-rata reward.
    scenario.next_tx(STRANGER);
    let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(pool_id);
    let reward = pool.claim_rewards(&mut s);
    assert!(reward.value() == 2_500);
    pool.unregister_stake(&mut s);
    test_scenario::return_shared(pool);

    balance::destroy_for_testing(stake::destroy(s));
    balance::destroy_for_testing(reward);
    destroy(cap);
    // The recording remains shared on-chain, as in production; nothing left
    // to tear down for it.
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = recording_royalty_pool::EPoolNotForRecording)]
/// `redeem_and_deposit` aborts when the pool was derived from a different
/// recording. Recording A's pool belongs to ADMIN; recording B (and its own
/// cap) belongs to STRANGER, who mistakenly references A's pool.
fun test_redeem_aborts_for_wrong_pool() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Recording A with its own pool, owned by ADMIN.
    scenario.next_tx(ADMIN);
    let (mut a_rec, a_cap) = new_recording_fixture(&mut scenario);
    let a_pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut a_rec,
        &a_cap,
    );
    let a_pool_id = a_pool.id();
    a_pool.share();

    // Recording B (no pool of its own), owned by STRANGER — a different
    // admin who will (mistakenly) try to fold its revenue into A's pool.
    scenario.next_tx(STRANGER);
    let (mut b_rec, b_cap) = new_recording_fixture(&mut scenario);
    let b_id = b_rec.id();

    // Register a stake against A's pool so the deposit doesn't abort on
    // ENoStakedShares (we want to hit EPoolNotForRecording specifically).
    scenario.next_tx(ADMIN);
    let mut s = new_stake(&mut scenario, 100);
    let mut a_pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(a_pool_id);
    a_pool.register_stake(&mut s);
    test_scenario::return_shared(a_pool);

    // Revenue lands in B's funds accumulator, sent by PAYER.
    scenario.next_tx(PAYER);
    balance::create_for_testing<TEST_CURRENCY>(100).send_funds(b_id.to_address());

    // Tx (STRANGER, holding b_cap): try to fold B's funds into A's pool —
    // should abort.
    scenario.next_tx(STRANGER);
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
/// recording. Recording A's pool belongs to ADMIN; recording B (and its own
/// cap) belongs to STRANGER, who mistakenly references A's pool.
fun test_receive_aborts_for_wrong_pool() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Recording A with its own pool, owned by ADMIN.
    scenario.next_tx(ADMIN);
    let (mut a_rec, a_cap) = new_recording_fixture(&mut scenario);
    let a_pool = recording_royalty_pool::initialize_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
        &mut a_rec,
        &a_cap,
    );
    let a_pool_id = a_pool.id();
    a_pool.share();

    // Recording B (no pool of its own), owned by STRANGER.
    scenario.next_tx(STRANGER);
    let (mut b_rec, b_cap) = new_recording_fixture(&mut scenario);
    let b_id = b_rec.id();

    // Register a stake against A's pool so the deposit doesn't abort on
    // ENoStakedShares (we want to hit EPoolNotForRecording specifically).
    scenario.next_tx(ADMIN);
    let mut s = new_stake(&mut scenario, 100);
    let mut a_pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> =
        scenario.take_shared_by_id(a_pool_id);
    a_pool.register_stake(&mut s);
    test_scenario::return_shared(a_pool);

    // PAYER sends a coin to B's address.
    scenario.next_tx(PAYER);
    let coin = coin::from_balance(
        balance::create_for_testing<TEST_CURRENCY>(100),
        scenario.ctx(),
    );
    let coin_id = object::id(&coin);
    transfer::public_transfer(coin, b_id.to_address());

    // Tx (STRANGER, holding b_cap): try to fold B's coin into A's pool —
    // should abort.
    scenario.next_tx(STRANGER);
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
