// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end scenarios for this package's full use case, run under
/// `sui::test_scenario`: every flow crosses real transaction boundaries with
/// distinct senders, and every shared object is genuinely shared and accessed
/// via `take_shared`, exactly as client PTBs compose it in production.
///
/// Scope: the composition's revenue leg, upstream included via test-only
/// dependencies (`modes = ["test"]`): release revenue distributed through the
/// production manifest must reach composition-share holders with no admin cap
/// in the path:
///
///   request_revenue_distribution → settle → finalize   (permissionless)
///     → recording pool → recording stakers claim       (stake-gated)
///     → routed_stake::sweep                   (permissionless)
///     → composition pool
///     → composition stakers claim             (stake-gated)
///
/// plus the cap-gated lifecycle edges: create/register at setup, and the
/// unregister/unstake exit that recovers the principal.
#[test_only]
module composition_routed_stake::composition_revenue_e2e_tests;

use composition_routed_stake::composition_routed_stake as crs;
use composition_royalty_pool::composition_royalty_pool;
use miso::composition::{Self, Composition, CompositionAdminCap};
use miso::recording::{Self, Recording, RecordingAdminCap};
use miso::release;
use miso::test_helpers;
use miso::track;
use recording_royalty_pool::recording_royalty_pool;
use release_revenue_distributor::release_revenue_distributor as distributor;
use routed_stake::routed_stake::{Self, RoutedStake};
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::unit_test::{assert_eq, destroy};
use sui::balance;
use sui::test_scenario::{Self, Scenario};

// Phantom marker types.
public struct REC {}
public struct COMP {}
public struct USD {}

// Actors. ADMIN performs the cap-gated setup; PAYER and STRANGER own nothing
// and prove the permissionless legs with different senders.
const ADMIN: address = @0xAD;
const PAYER: address = @0xFA;
const STRANGER: address = @0x51;

/// Cap-gated setup (as ADMIN, tx 1): a composition and a recording of it;
/// both pools created and shared; artist stake (800 REC) registered; the
/// composition's settled 200-share grant wrapped in a shared routed stake and
/// registered; a fan stake (1000 COMP) registered with the composition pool.
fun setup_shared(
    ts: &mut Scenario,
): (
    Composition<COMP>,
    CompositionAdminCap<COMP>,
    Recording<REC, COMP>,
    RecordingAdminCap<REC>,
    Stake<REC>,
    Stake<COMP>,
) {
    let (mut comp, comp_cap) =
        composition::new_for_testing<COMP>(b"Song".to_string(), 2000, ts.ctx());
    let (mut rec, rec_cap) = recording::new_for_testing<REC, COMP>(comp.id(), ts.ctx());

    let mut rec_pool =
        recording_royalty_pool::initialize_pool<REC, COMP, USD>(&mut rec, &rec_cap);
    let mut comp_pool =
        composition_royalty_pool::initialize_pool<COMP, USD>(&mut comp, &comp_cap);

    let mut artist_stake = stake::new(balance::create_for_testing<REC>(800), ts.ctx());
    rec_pool.register_stake(&mut artist_stake);

    // The composition's settled royalty grant (sent by `miso::recording::new`
    // in production) wrapped in a routed stake and registered.
    balance::create_for_testing<REC>(200).send_funds(comp.id().to_address());
    let mut routed = crs::create_stake<REC, COMP>(&mut comp, &comp_cap, &rec, 200, ts.ctx());
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut routed, &mut rec_pool);

    let mut fan_stake = stake::new(balance::create_for_testing<COMP>(1000), ts.ctx());
    comp_pool.register_stake(&mut fan_stake);

    rec_pool.share();
    comp_pool.share();
    routed_stake::share(routed);

    (comp, comp_cap, rec, rec_cap, artist_stake, fan_stake)
}

/// The flagship path. Recording cap table: artist 800 REC staked directly,
/// composition 200 REC via its routed stake. 1_000_000 USD of recording
/// revenue must land 800_000 with the artist and 200_000 with the fan (via
/// the composition's pool) — conservation exact, both pools drained, every
/// post-setup transaction sent by someone with no capability whatsoever.
#[test]
fun revenue_reaches_composition_share_holders_pro_rata() {
    let mut ts = test_scenario::begin(ADMIN);
    let (comp, comp_cap, rec, rec_cap, mut artist_stake, mut fan_stake) =
        setup_shared(&mut ts);
    let comp_id = comp.id();

    // --- Tx 2 (PAYER, owns nothing): release revenue distributed through
    // the production manifest against the shared pool ---
    ts.next_tx(PAYER);
    let release_id = test_helpers::fake_id(ts.ctx());
    let tracks = vector[track::new_for_testing(comp.id(), rec.id(), release_id, 10000)];
    let (rel, rel_cap) = release::new_for_testing(b"Single".to_string(), tracks, ts.ctx());
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    let mut m = distributor::request_revenue_distribution(
        &rel,
        balance::create_for_testing<USD>(1_000_000),
    );
    m.settle_track_revenue(0, &mut rec_pool);
    m.finalize_revenue_distribution();
    assert_eq!(rec_pool.balance().value(), 1_000_000);
    test_scenario::return_shared(rec_pool);

    // --- Tx 3 (STRANGER): permissionless sweep of the composition's cut ---
    ts.next_tx(STRANGER);
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    let mut comp_pool = ts.take_shared<RoyaltyPool<COMP, USD>>();
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();
    routed_stake::sweep<REC, COMP, USD>(&mut routed, &mut rec_pool, &mut comp_pool, comp_id);
    assert_eq!(comp_pool.balance().value(), 200_000);
    test_scenario::return_shared(rec_pool);
    test_scenario::return_shared(comp_pool);
    test_scenario::return_shared(routed);

    // --- Tx 4 (ADMIN): stake holders claim from the shared pools ---
    ts.next_tx(ADMIN);
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    let mut comp_pool = ts.take_shared<RoyaltyPool<COMP, USD>>();
    let artist_reward = rec_pool.claim_rewards(&mut artist_stake);
    let fan_reward = comp_pool.claim_rewards(&mut fan_stake);
    assert_eq!(artist_reward.value(), 800_000);
    assert_eq!(fan_reward.value(), 200_000);
    assert_eq!(artist_reward.value() + fan_reward.value(), 1_000_000);
    assert_eq!(rec_pool.balance().value(), 0);
    assert_eq!(comp_pool.balance().value(), 0);
    test_scenario::return_shared(rec_pool);
    test_scenario::return_shared(comp_pool);

    destroy(artist_reward);
    destroy(fan_reward);
    destroy(artist_stake);
    destroy(fan_stake);
    destroy(rel);
    destroy(rel_cap);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    ts.end();
}

/// Multiple revenue rounds accumulate on the shared routed stake across
/// transactions, a stranger sweeps the accrued total, and the exit path
/// (unregister → unstake) recovers the exact principal — the routed stake's
/// full lifecycle under shared-object mechanics.
#[test]
fun routed_stake_earns_across_rounds_and_exits_cleanly() {
    let mut ts = test_scenario::begin(ADMIN);
    let (mut comp, comp_cap, rec, rec_cap, artist_stake, mut fan_stake) =
        setup_shared(&mut ts);
    let comp_id = comp.id();

    // --- Tx 2 & 3 (PAYER): two revenue rounds of 100_000 each ---
    2u64.do!(|_| {
        ts.next_tx(PAYER);
        let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
        rec_pool.deposit(balance::create_for_testing<USD>(100_000));
        test_scenario::return_shared(rec_pool);
    });

    // --- Tx 4 (STRANGER): sweep the accrued total — 200/1000 of 200_000 ---
    ts.next_tx(STRANGER);
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    let mut comp_pool = ts.take_shared<RoyaltyPool<COMP, USD>>();
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();
    routed_stake::sweep<REC, COMP, USD>(&mut routed, &mut rec_pool, &mut comp_pool, comp_id);
    assert_eq!(comp_pool.balance().value(), 40_000);
    test_scenario::return_shared(rec_pool);
    test_scenario::return_shared(comp_pool);
    test_scenario::return_shared(routed);

    // --- Tx 5 (ADMIN): exit — unregister passes only because the sweep
    // drained claimables; the wrapper returns the exact principal ---
    ts.next_tx(ADMIN);
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    let mut comp_pool = ts.take_shared<RoyaltyPool<COMP, USD>>();
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();
    crs::unregister<REC, COMP, USD>(&mut comp, &comp_cap, &mut routed, &mut rec_pool);
    let principal = crs::unstake<REC, COMP>(&mut comp, &comp_cap, &mut routed, ts.ctx());
    assert_eq!(principal.value(), 200);
    assert!(!routed.has_stake());
    // The fan's claim of the swept total still works after the exit.
    let fan_reward = comp_pool.claim_rewards(&mut fan_stake);
    assert_eq!(fan_reward.value(), 40_000);
    test_scenario::return_shared(rec_pool);
    test_scenario::return_shared(comp_pool);
    test_scenario::return_shared(routed);

    destroy(principal);
    destroy(fan_reward);
    destroy(artist_stake);
    destroy(fan_stake);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    ts.end();
}
