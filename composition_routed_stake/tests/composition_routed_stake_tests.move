// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module composition_routed_stake::composition_routed_stake_tests;

use composition_routed_stake::composition_routed_stake as crs;
use miso::composition::{Self, Composition, CompositionAdminCap};
use miso::recording::{Self, Recording, RecordingAdminCap};
use routed_stake::routed_stake::{Self, RoutedStake};
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::unit_test::{assert_eq, destroy};
use sui::balance;
use sui::test_scenario::{Self, Scenario};

// abort_code 1 mirrors `royalty_pool::stake::EPoolsRegistered`, which is
// package-private in `royalty_pool` and cannot be referenced from this
// package — the numeric mirror must be kept in sync with stake.move.
const EPoolsRegistered: u64 = 1;

// Phantom marker types for the share/currency parameters.
public struct REC {}
public struct COMP {}
public struct USD {}

// Actors, matching the flagship e2e's convention. ADMIN performs all
// cap-gated setup/lifecycle calls here; STRANGER owns nothing and proves the
// permissionless sweep leg with a different sender than the one who set up
// the position.
const ADMIN: address = @0xAD;
const PAYER: address = @0xFA;
const STRANGER: address = @0x51;

fun setup(
    ctx: &mut TxContext,
): (Composition<COMP>, CompositionAdminCap<COMP>, Recording<REC, COMP>, RecordingAdminCap<REC>) {
    let (comp, comp_cap) = composition::new_for_testing<COMP>(b"Song".to_string(), 1500, ctx);
    let (rec, rec_cap) = recording::new_for_testing<REC, COMP>(comp.id(), ctx);
    (comp, comp_cap, rec, rec_cap)
}

/// Seed the composition's address balance and wrap `value` shares in a routed
/// stake, as the recording-creation settlement + `create_stake` would.
fun mk_stake(
    comp: &mut Composition<COMP>,
    comp_cap: &CompositionAdminCap<COMP>,
    rec: &Recording<REC, COMP>,
    value: u64,
    ctx: &mut TxContext,
): routed_stake::RoutedStake<REC, COMP> {
    balance::create_for_testing<REC>(value).send_funds(comp.id().to_address());
    crs::create_stake<REC, COMP>(comp, comp_cap, rec, value, ctx)
}

/// The `RoutedStake` wrapper is a shared object in production (`share`'s only
/// consumer is the caller of `create_stake`, and the module doc calls it out
/// explicitly as "safe to share"). This test runs the full
/// create → share → unstake → restake lifecycle across real transaction
/// boundaries with the wrapper genuinely shared and re-accessed via
/// `take_shared`/`return_shared`, matching that production shape. All calls
/// remain cap-gated, so a single ADMIN sender is correct here (contrast the
/// permissionless `sweep` test below, which uses a distinct sender).
#[test]
fun create_stake_redeems_address_balance_and_unstake_round_trips() {
    let mut ts = test_scenario::begin(ADMIN);
    let (mut comp, comp_cap, rec, rec_cap) = setup(ts.ctx());
    let comp_id = comp.id();

    let routed = mk_stake(&mut comp, &comp_cap, &rec, 1000, ts.ctx());
    routed_stake::share(routed);

    // --- Tx 2 (ADMIN, cap-gated): the wrapper is now a genuinely shared
    // object, taken back via `take_shared` exactly as a client PTB would ---
    ts.next_tx(ADMIN);
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();

    // The wrapper is the composition's derived routed stake for REC.
    assert_eq!(routed.id().to_address(), routed_stake::derived_address<REC>(comp_id));
    assert_eq!(routed.value(), 1000);

    // Unstake with no pool registrations returns the full principal.
    let coin = crs::unstake<REC, COMP>(&mut comp, &comp_cap, &mut routed, ts.ctx());
    assert_eq!(coin.value(), 1000);
    assert!(!routed.has_stake());

    // The emptied wrapper is refillable from the address balance.
    balance::create_for_testing<REC>(500).send_funds(comp.id().to_address());
    crs::restake<REC, COMP>(&mut comp, &comp_cap, &mut routed, 500, ts.ctx());
    assert_eq!(routed.value(), 500);

    test_scenario::return_shared(routed);
    destroy(coin);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    ts.end();
}

/// Same shared-object shape as above, this time exercising `register` /
/// `sweep` / `unregister`: the routed stake and both pools are genuinely
/// shared, and the permissionless `sweep` is executed by STRANGER — a sender
/// who owns nothing — proving permissionlessness by sender, not merely by
/// the absence of a cap parameter. Distinct from the flagship e2e's pro-rata
/// case: here the composition is the pool's *sole* staker, so it earns the
/// entire deposit (100%, not a split) — a distinct arithmetic case worth
/// covering on its own.
#[test]
fun sweep_routes_recording_royalties_to_the_composition_pool() {
    let mut ts = test_scenario::begin(ADMIN);
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ts.ctx());
    let comp_id = comp.id();

    let routed = mk_stake(&mut comp, &comp_cap, &rec, 1000, ts.ctx());
    let rec_pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    let mut comp_pool = pool::new<COMP, USD>(comp.uid_mut(&comp_cap));
    let mut holder = stake::new(balance::create_for_testing<COMP>(100), ts.ctx());
    comp_pool.register_stake(&mut holder);
    rec_pool.share();
    comp_pool.share();
    routed_stake::share(routed);

    // --- Tx 2 (ADMIN, cap-gated): register the shared wrapper against the
    // shared recording pool ---
    ts.next_tx(ADMIN);
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut routed, &mut rec_pool);
    test_scenario::return_shared(routed);
    test_scenario::return_shared(rec_pool);

    // --- Tx 3 (PAYER, owns nothing): fund the recording pool ---
    ts.next_tx(PAYER);
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    rec_pool.deposit(balance::create_for_testing<USD>(500));
    test_scenario::return_shared(rec_pool);

    // --- Tx 4 (STRANGER, owns nothing): permissionless sweep. Composition is
    // the recording pool's sole staker, so it earns the deposit in full ---
    ts.next_tx(STRANGER);
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    let mut comp_pool = ts.take_shared<RoyaltyPool<COMP, USD>>();
    routed.sweep(&mut rec_pool, &mut comp_pool, comp_id);

    // The reward never surfaced as a free Coin: it sits in the composition's
    // pool, claimable by the registered composition-share holder in full.
    assert_eq!(comp_pool.balance().value(), 500);
    let holder_reward = comp_pool.claim_rewards(&mut holder);
    assert_eq!(holder_reward.value(), 500);
    test_scenario::return_shared(routed);
    test_scenario::return_shared(rec_pool);
    test_scenario::return_shared(comp_pool);

    // --- Tx 5 (ADMIN, cap-gated): rewards drained → unregister succeeds →
    // principal is reclaimable ---
    ts.next_tx(ADMIN);
    let mut routed = ts.take_shared<RoutedStake<REC, COMP>>();
    let mut rec_pool = ts.take_shared<RoyaltyPool<REC, USD>>();
    crs::unregister<REC, COMP, USD>(&mut comp, &comp_cap, &mut routed, &mut rec_pool);
    let principal = crs::unstake<REC, COMP>(&mut comp, &comp_cap, &mut routed, ts.ctx());
    assert_eq!(principal.value(), 1000);

    test_scenario::return_shared(routed);
    test_scenario::return_shared(rec_pool);

    destroy(holder_reward);
    destroy(holder);
    destroy(principal);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    ts.end();
}

/// A local-invariant abort test: `register` rejects a pool that was not
/// derived from the given recording, a pure address-comparison check that
/// does not depend on whether the pool or wrapper is shared. The flagship
/// e2e and the two scenario tests above already cover this package's
/// shared-object/distinct-sender production shape exhaustively; scenario
/// mechanics would add nothing to this negative-path check, so it stays in
/// single-transaction `tx_context::dummy()` style.
#[test, expected_failure(abort_code = crs::EPoolNotForRecording, location = composition_routed_stake::composition_routed_stake)]
fun register_rejects_pool_from_other_recording() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, rec1, rec_cap1) = setup(ctx);
    destroy(rec_cap1);
    // A second recording of the same share type (only constructible in tests),
    // with its own pool — same type as rec1's pool but derived from rec2.
    let (mut rec2, rec_cap2) = recording::new_for_testing<REC, COMP>(comp.id(), ctx);
    let mut wrong_pool = pool::new<REC, USD>(rec2.uid_mut(&rec_cap2));

    let mut routed = mk_stake(&mut comp, &comp_cap, &rec1, 1000, ctx);

    // Registering rec1's stake against rec2's pool must abort (EPoolNotForRecording).
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec1, &mut routed, &mut wrong_pool);
    abort
}

/// Another local-invariant abort test, this time on the lib's own
/// `stake::destroy` guard (registered stakes cannot unstake). Same rationale
/// as above: this is a same-transaction state check, not an ownership flow —
/// dummy-ctx style is appropriate.
#[test, expected_failure(abort_code = EPoolsRegistered, location = royalty_pool::stake)]
fun unstake_while_registered_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap, mut rec, rec_cap) = setup(ctx);

    let mut routed = mk_stake(&mut comp, &comp_cap, &rec, 1000, ctx);
    let mut rec_pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    crs::register<REC, COMP, USD>(&mut comp, &comp_cap, &rec, &mut routed, &mut rec_pool);

    // Still registered → stake::destroy aborts EPoolsRegistered.
    let _coin = crs::unstake<REC, COMP>(&mut comp, &comp_cap, &mut routed, ctx);
    abort
}

/// Documents a type-level authorization property, not an ownership flow —
/// dummy-ctx style is appropriate; see the in-body comment for why no
/// wrong-cap test exists here.
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
    // comp_b's cap authorizes create/register on comp_a. The cap's security
    // rests entirely on the `share::initialize` 1:1 type↔object invariant
    // above — do not add a "wrong cap aborts" test here; there is no id check
    // for it to trip.
    let mut routed = mk_stake(&mut comp_a, &cap_b, &rec, 1000, ctx);
    let mut rec_pool = pool::new<REC, USD>(rec.uid_mut(&rec_cap));
    crs::register<REC, COMP, USD>(&mut comp_a, &cap_b, &rec, &mut routed, &mut rec_pool);

    destroy(routed);
    destroy(rec_pool);
    destroy(comp_a);
    destroy(cap_a);
    destroy(comp_b);
    destroy(cap_b);
    destroy(rec);
    destroy(rec_cap);
}
