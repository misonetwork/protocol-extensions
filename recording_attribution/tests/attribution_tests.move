// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_attribution::attribution_tests;

use miso::recording::{Self, Recording, RecordingAdminCap};
use recording_attribution::attribution;
use recording_attribution::license;
use royalty_pool::pool;
use royalty_pool::stake;
use std::unit_test::{assert_eq, destroy};
use sui::balance;

public struct SOURCE_SHARE() has drop;
public struct GEN_SHARE() has drop;
public struct TEST_CURRENCY() has drop;
/// Parent-composition identity for test recordings. Attribution operates on
/// recording shares and ids, never the composition phantom, so one witness
/// stands in for every recording's parent here.
public struct COMPOSITION() has drop;

// === Helpers ===

fun new_recording<Share>(
    ctx: &mut TxContext,
): (Recording<Share, COMPOSITION>, RecordingAdminCap<Share>) {
    recording::new_for_testing<Share, COMPOSITION>(
        b"Recording".to_string(),
        ctx,
    )
}

/// A source recording with an attribution license attached — the rights
/// holder's opt-in that `attribution::new` requires.
fun licensed_source<Share>(
    ctx: &mut TxContext,
): (Recording<Share, COMPOSITION>, RecordingAdminCap<Share>) {
    let (mut rec, cap) = new_recording<Share>(ctx);
    license::attach(&mut rec, &cap, vector[b"train".to_string()]);
    (rec, cap)
}

// === Tests ===

#[test]
/// Edge creation: custody, identity, and derived address.
fun test_new_edge() {
    let ctx = &mut tx_context::dummy();
    let (mut gen, gen_cap) = new_recording<GEN_SHARE>(ctx);
    let (source, source_cap) = licensed_source<SOURCE_SHARE>(ctx);

    let edge = attribution::new(
        &gen_cap,
        &mut gen,
        &source,
        balance::create_for_testing<GEN_SHARE>(2_500),
        ctx,
    );

    assert_eq!(edge.staked_shares(), 2_500);
    assert_eq!(edge.source_recording_id(), source.id());
    assert_eq!(edge.generative_recording_id(), gen.id());
    assert_eq!(
        edge.id().to_address(),
        attribution::derive_attribution_address<SOURCE_SHARE>(gen.id()),
    );

    destroy(edge);
    destroy(gen);
    destroy(gen_cap);
    destroy(source);
    destroy(source_cap);
}

#[test]
#[expected_failure(abort_code = attribution::ESourceNotLicensed)]
/// A source with no attribution license attached is denied — attribution is
/// opt-in, so absence is denial.
fun test_new_rejects_unlicensed_source() {
    let ctx = &mut tx_context::dummy();
    let (mut gen, gen_cap) = new_recording<GEN_SHARE>(ctx);
    let (source, source_cap) = new_recording<SOURCE_SHARE>(ctx);

    let edge = attribution::new(
        &gen_cap,
        &mut gen,
        &source,
        balance::create_for_testing<GEN_SHARE>(2_500),
        ctx,
    );

    destroy(edge);
    destroy(gen);
    destroy(gen_cap);
    destroy(source);
    destroy(source_cap);
}

#[test]
#[expected_failure]
/// The derived key admits one edge per (generated recording, source type).
fun test_duplicate_edge_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut gen, gen_cap) = new_recording<GEN_SHARE>(ctx);
    let (source, source_cap) = licensed_source<SOURCE_SHARE>(ctx);

    let edge_a = attribution::new(
        &gen_cap,
        &mut gen,
        &source,
        balance::create_for_testing<GEN_SHARE>(2_500),
        ctx,
    );
    let edge_b = attribution::new(
        &gen_cap,
        &mut gen,
        &source,
        balance::create_for_testing<GEN_SHARE>(2_500),
        ctx,
    );

    destroy(edge_a);
    destroy(edge_b);
    destroy(gen);
    destroy(gen_cap);
    destroy(source);
    destroy(source_cap);
}

#[test]
/// Full money path: revenue deposited into the generated recording's pool
/// is claimed by the edge and lands in the source recording's pool, where
/// the source's own shareholder claims it. A second route is a no-op.
fun test_register_and_route() {
    let ctx = &mut tx_context::dummy();
    let (mut gen, gen_cap) = new_recording<GEN_SHARE>(ctx);
    let (mut source, source_cap) = licensed_source<SOURCE_SHARE>(ctx);

    let mut edge = attribution::new(
        &gen_cap,
        &mut gen,
        &source,
        balance::create_for_testing<GEN_SHARE>(2_500),
        ctx,
    );

    // Generated recording's pool: edge registers, then revenue arrives.
    let mut gen_pool = pool::new<GEN_SHARE, TEST_CURRENCY>(gen.uid_mut(&gen_cap));
    edge.register(&mut gen_pool);
    gen_pool.deposit(balance::create_for_testing<TEST_CURRENCY>(1_000));
    assert_eq!(edge.pending_rewards(&gen_pool), 1_000);

    // Source recording's pool with one shareholder staked.
    let mut source_pool = pool::new<SOURCE_SHARE, TEST_CURRENCY>(source.uid_mut(&source_cap));
    let mut holder = stake::new(balance::create_for_testing<SOURCE_SHARE>(100), ctx);
    source_pool.register_stake(&mut holder);

    edge.route(&mut gen_pool, &mut source_pool);
    assert_eq!(source_pool.balance().value(), 1_000);
    assert_eq!(edge.pending_rewards(&gen_pool), 0);

    // Nothing accrued → no-op, no abort.
    edge.route(&mut gen_pool, &mut source_pool);
    assert_eq!(source_pool.balance().value(), 1_000);

    // The source's shareholder claims the routed revenue pro-rata (sole staker).
    let reward = source_pool.claim_rewards(&mut holder);
    assert_eq!(reward.value(), 1_000);

    destroy(reward);
    destroy(holder);
    destroy(source_pool);
    destroy(gen_pool);
    destroy(edge);
    destroy(gen);
    destroy(gen_cap);
    destroy(source);
    destroy(source_cap);
}

#[test]
#[expected_failure(abort_code = 0, location = royalty_pool::pool)]
/// A pool derived from a different parent cannot capture the edge's
/// registration slot.
fun test_register_rejects_foreign_pool() {
    let ctx = &mut tx_context::dummy();
    let (mut gen, gen_cap) = new_recording<GEN_SHARE>(ctx);
    let (mut source, source_cap) = licensed_source<SOURCE_SHARE>(ctx);

    let mut edge = attribution::new(
        &gen_cap,
        &mut gen,
        &source,
        balance::create_for_testing<GEN_SHARE>(2_500),
        ctx,
    );
    // Right type signature, wrong parent: derived from the source recording.
    let mut foreign_pool = pool::new<GEN_SHARE, TEST_CURRENCY>(source.uid_mut(&source_cap));

    edge.register(&mut foreign_pool);

    destroy(foreign_pool);
    destroy(edge);
    destroy(gen);
    destroy(gen_cap);
    destroy(source);
    destroy(source_cap);
}
