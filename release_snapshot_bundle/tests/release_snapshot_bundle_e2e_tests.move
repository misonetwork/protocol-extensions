// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end scenarios for this package's full use case, run under
/// `sui::test_scenario`: the release is published and genuinely shared first
/// — the production shape, since `miso::release` create-and-publish is atomic
/// and every release that exists on-chain is `Published` and shared — and the
/// snapshot-bundle slot is set on it via `take_shared` in a LATER
/// transaction, exactly as a client PTB would compose it. Reading is proven
/// permissionless by a sender who owns nothing; the wrong-cap and
/// double-attach aborts are proven against the shared, published object too.
#[test_only]
module release_snapshot_bundle::release_snapshot_bundle_e2e_tests;

use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use ori::walrus_data;
use release_snapshot_bundle::release_snapshot_bundle as bundle;
use std::unit_test::{assert_eq, destroy};
use sui::clock;
use sui::event;
use sui::test_scenario::{Self, Scenario};

// ADMIN performs the cap-gated setup and the cap-gated write; STRANGER owns
// nothing and proves the permissionless read, and stands in as the adversary
// for the wrong-cap and double-attach aborts.
const ADMIN: address = @0xAD;
const STRANGER: address = @0x51;

// Mirrored from miso::release::EUnauthorized (private there).
const EUnauthorized: u64 = 0;

/// Creates a minimal one-track release and publishes it, which shares it —
/// core's create-and-publish is atomic, so this is the only way a `Release`
/// ever reaches chain state. Returns the admin cap; the release itself is
/// only reachable afterward via `take_shared`.
fun publish_and_share_release(ts: &mut Scenario): ReleaseAdminCap {
    let rel_id = test_helpers::fake_id(ts.ctx());
    let comp_id = test_helpers::fake_id(ts.ctx());
    let rec_id = test_helpers::fake_id(ts.ctx());
    let tracks = vector[track::new_for_testing(comp_id, rec_id, rel_id, 10000u16)];
    let (rel, cap) = release::new_for_testing(b"Album".to_string(), tracks, ts.ctx());
    let clk = clock::create_for_testing(ts.ctx());
    rel.publish(&cap, &clk);
    clk.destroy_for_testing();
    cap
}

/// The production flow: release published and shared by ADMIN in tx 1, the
/// bundle set on it by ADMIN (cap holder) in tx 2, and read back — including
/// the emitted event's full payload — by STRANGER (owns nothing) in tx 3.
#[test]
fun set_after_publish_and_share_then_read_back_by_a_stranger() {
    let mut ts = test_scenario::begin(ADMIN);
    let cap = publish_and_share_release(&mut ts);

    // --- Tx 2 (ADMIN, cap holder): attach the bundle to the shared release ---
    ts.next_tx(ADMIN);
    let mut rel = ts.take_shared<Release>();
    let rel_id = rel.id();
    assert!(rel.is_published_state());
    assert!(!bundle::has_snapshot_bundle(&rel));

    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(42));

    assert!(bundle::has_snapshot_bundle(&rel));
    assert_eq!(bundle::snapshot_bundle(&rel).blob_id(), 42);
    test_scenario::return_shared(rel);

    let events = event::events_by_type<bundle::SnapshotBundleSetEvent>();
    assert_eq!(events.length(), 1);
    let (event_release_id, reference) = bundle::set_event_fields(&events[0]);
    assert_eq!(event_release_id, rel_id);
    assert_eq!(reference, walrus_data::new_blob(42));

    // --- Tx 3 (STRANGER, owns nothing): the read is permissionless ---
    ts.next_tx(STRANGER);
    let rel = ts.take_shared<Release>();
    assert!(bundle::has_snapshot_bundle(&rel));
    assert_eq!(bundle::snapshot_bundle(&rel).blob_id(), 42);
    test_scenario::return_shared(rel);

    destroy(cap);
    ts.end();
}

/// A cap authorizing a different release cannot set the slot on this one —
/// enforced by `Release::uid_mut`'s own authorization check, even after the
/// target release is published and shared.
#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun set_with_wrong_cap_after_publish_aborts() {
    let mut ts = test_scenario::begin(ADMIN);
    let cap = publish_and_share_release(&mut ts);

    // A second, unrelated release — kept unpublished; only its cap matters.
    ts.next_tx(STRANGER);
    let rel_id = test_helpers::fake_id(ts.ctx());
    let comp_id = test_helpers::fake_id(ts.ctx());
    let rec_id = test_helpers::fake_id(ts.ctx());
    let other_tracks = vector[track::new_for_testing(comp_id, rec_id, rel_id, 10000u16)];
    let (other_rel, other_cap) = release::new_for_testing(
        b"Other".to_string(),
        other_tracks,
        ts.ctx(),
    );

    let mut rel = ts.take_shared<Release>();
    bundle::set_snapshot_bundle(&mut rel, &other_cap, walrus_data::new_blob(1));

    // Unreachable, but the compiler requires all non-drop values consumed.
    destroy(other_rel);
    destroy(other_cap);
    test_scenario::return_shared(rel);
    destroy(cap);
    abort
}

/// The write-once guarantee holds against the shared, published object too:
/// a second `set_snapshot_bundle` in a later transaction — even by the
/// legitimate cap holder — aborts rather than swapping the buyer-facing
/// pointer out from under them.
#[test, expected_failure(abort_code = bundle::EBundleAlreadySet)]
fun double_attach_after_publish_aborts() {
    let mut ts = test_scenario::begin(ADMIN);
    let cap = publish_and_share_release(&mut ts);

    // --- Tx 2 (ADMIN): first attach succeeds ---
    ts.next_tx(ADMIN);
    let mut rel = ts.take_shared<Release>();
    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(1));
    test_scenario::return_shared(rel);

    // --- Tx 3 (ADMIN): second attach aborts — no unset, no replace ---
    ts.next_tx(ADMIN);
    let mut rel = ts.take_shared<Release>();
    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(2));

    // Unreachable, but the compiler requires all non-drop values consumed.
    test_scenario::return_shared(rel);
    destroy(cap);
    abort
}
