// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end scenarios for `release_registry`'s full use case, run under
/// `sui::test_scenario`: every flow crosses real transaction boundaries with
/// distinct senders, and the registry is genuinely shared and re-accessed
/// via `take_shared`, exactly as client PTBs compose it in production.
///
/// Upstream context (`Composition`, `Recording`, `Track`) is reached via
/// `miso`, this package's only dependency (a plain, non-test dependency —
/// core's production API and `#[test_only]` test-helper surface are both
/// exposed through it).
#[test_only]
module release_registry::release_registry_e2e_tests;

use miso::composition::{Self, Composition};
use miso::recording::{Self, Recording};
use miso::release::Release;
use miso::test_helpers::{Self, CompositionShare, RecordingShare};
use miso::track;
use release_registry::release_registry::{Self, ReleaseRegistry};
use std::unit_test::{assert_eq, destroy};
use sui::event;
use sui::test_scenario;

const SONGWRITER: address = @0xA1;
const ARTIST: address = @0xA2;
const LABEL_A: address = @0xA3;
const LABEL_B: address = @0xA4;
const READER: address = @0xBEEF;

const ROYALTY_RATE_BPS: u16 = 1500;
const NONCE: u256 = 42;
const NONCE_A: u256 = 101;
const NONCE_B: u256 = 202;

// === End-to-end through the canonical registry ===

/// The full production flow through the canonical (init-created, shared)
/// registry: a songwriter and artist publish their work, the artist consents
/// to a specific future release via cap-gated `track::new`, and a label
/// assembles and publishes the release through the registry — landing at
/// exactly the id predicted up front.
#[test]
fun full_flow_through_canonical_registry() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    release_registry::init_for_testing(scenario.ctx());

    // === Tx 1 (SONGWRITER): create and publish the composition ===
    scenario.next_tx(SONGWRITER);
    let (comp, comp_cap) = composition::new_for_testing<CompositionShare>(
        b"Song".to_string(),
        ROYALTY_RATE_BPS,
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    comp.publish(&comp_cap, &clock); // shares the composition
    clock.destroy_for_testing();
    destroy(comp_cap);

    // === Tx 2 (ARTIST): create and publish a recording of it ===
    scenario.next_tx(ARTIST);
    let comp = scenario.take_shared<Composition<CompositionShare>>();
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        comp.id(),
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rec.publish(&rec_cap, &clock); // shares the recording
    clock.destroy_for_testing();
    test_scenario::return_shared(comp);

    // === Tx 3 (ARTIST): derive the target id and consent via track::new ===
    scenario.next_tx(ARTIST);
    let rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let registry = scenario.take_shared<ReleaseRegistry>();
    let recording_id = rec.id();
    let predicted_release_id = registry.derive_target_release_id(
        vector[recording_id],
        vector[10000u64],
        NONCE,
    );
    let t = track::new(&rec_cap, &rec, predicted_release_id, 10000);
    test_scenario::return_shared(rec);
    test_scenario::return_shared(registry);

    // === Tx 4 (LABEL_A): assemble and publish the release through the registry ===
    scenario.next_tx(LABEL_A);
    let mut registry = scenario.take_shared<ReleaseRegistry>();
    let (rel, rel_cap) = registry.new_release(b"Single".to_string(), vector[t], NONCE);
    // The claimed id must equal the prediction the track was bound to.
    assert_eq!(rel.id(), predicted_release_id);
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel.publish(&rel_cap, &clock); // verifies track assignment, shares
    clock.destroy_for_testing();
    destroy(rel_cap);
    test_scenario::return_shared(registry);

    // === Tx 5 (READER): the published release is publicly consistent ===
    scenario.next_tx(READER);
    let rel = scenario.take_shared<Release>();
    assert!(rel.is_published_state());
    assert_eq!(rel.id(), predicted_release_id);
    assert_eq!(*rel.title(), b"Single".to_string());
    assert_eq!(rel.tracks().length(), 1);
    let track_ref = &rel.tracks()[0];
    assert!(track_ref.is_assigned_state());
    assert_eq!(track_ref.recording_id(), recording_id);
    test_scenario::return_shared(rel);

    destroy(rec_cap);
    scenario.end();
}

// === Two senders, one shared registry ===

/// Two different senders — LABEL_A and LABEL_B, each owning nothing before
/// their own transaction — independently create and publish a release
/// through the ONE canonical shared registry, in separate later
/// transactions, neither aware of the other. Proves the registry serves
/// unrelated releases from unrelated senders without collision, and that
/// each release is correctly parented to the one shared registry: both
/// claimed ids match what `derive_target_release_id` predicts against that
/// same registry's own id (same recording, distinct nonces), both releases
/// end up genuinely shared and independently readable by id afterward, and
/// the two are distinct objects.
#[test]
fun two_senders_create_releases_through_one_shared_registry() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    release_registry::init_for_testing(scenario.ctx());

    // === Tx 1 (SONGWRITER): create and publish the shared composition ===
    scenario.next_tx(SONGWRITER);
    let (comp, comp_cap) = composition::new_for_testing<CompositionShare>(
        b"Song".to_string(),
        ROYALTY_RATE_BPS,
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    comp.publish(&comp_cap, &clock); // shares the composition
    clock.destroy_for_testing();
    destroy(comp_cap);

    // === Tx 2 (ARTIST): create and publish a recording of it ===
    scenario.next_tx(ARTIST);
    let comp = scenario.take_shared<Composition<CompositionShare>>();
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        comp.id(),
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rec.publish(&rec_cap, &clock); // shares the recording
    clock.destroy_for_testing();
    test_scenario::return_shared(comp);

    // === Tx 3 (ARTIST): predict two distinct release ids under the SAME
    // registry (same recording, distinct nonces) and consent to each via
    // track::new ===
    scenario.next_tx(ARTIST);
    let rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let registry = scenario.take_shared<ReleaseRegistry>();
    let recording_id = rec.id();
    let predicted_id_a = registry.derive_target_release_id(
        vector[recording_id],
        vector[10000u64],
        NONCE_A,
    );
    let predicted_id_b = registry.derive_target_release_id(
        vector[recording_id],
        vector[10000u64],
        NONCE_B,
    );
    assert!(predicted_id_a != predicted_id_b);
    let track_a = track::new(&rec_cap, &rec, predicted_id_a, 10000);
    let track_b = track::new(&rec_cap, &rec, predicted_id_b, 10000);
    test_scenario::return_shared(rec);
    test_scenario::return_shared(registry);

    // === Tx 4 (LABEL_A): owns nothing beforehand; assembles and publishes
    // its own release through the one shared registry ===
    scenario.next_tx(LABEL_A);
    let mut registry = scenario.take_shared<ReleaseRegistry>();
    let (rel_a, cap_a) = registry.new_release(
        b"Label A Single".to_string(),
        vector[track_a],
        NONCE_A,
    );
    assert_eq!(rel_a.id(), predicted_id_a);
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel_a.publish(&cap_a, &clock); // shares rel_a
    clock.destroy_for_testing();
    destroy(cap_a);
    test_scenario::return_shared(registry);

    // === Tx 5 (LABEL_B): a different sender, owning nothing beforehand and
    // unaware of LABEL_A, does the same through the SAME shared registry ===
    scenario.next_tx(LABEL_B);
    let mut registry = scenario.take_shared<ReleaseRegistry>();
    let (rel_b, cap_b) = registry.new_release(
        b"Label B Single".to_string(),
        vector[track_b],
        NONCE_B,
    );
    assert_eq!(rel_b.id(), predicted_id_b);
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel_b.publish(&cap_b, &clock); // shares rel_b
    clock.destroy_for_testing();
    destroy(cap_b);
    test_scenario::return_shared(registry);

    // === Tx 6 (READER): both releases are independently readable, distinct,
    // and each correctly parented to the one registry ===
    scenario.next_tx(READER);
    let registry = scenario.take_shared<ReleaseRegistry>();
    let rel_a = scenario.take_shared_by_id<Release>(predicted_id_a);
    let rel_b = scenario.take_shared_by_id<Release>(predicted_id_b);

    // Distinct objects, each at the id its own track consented to.
    assert!(rel_a.id() != rel_b.id());
    assert_eq!(rel_a.id(), predicted_id_a);
    assert_eq!(rel_b.id(), predicted_id_b);
    assert!(rel_a.is_published_state());
    assert!(rel_b.is_published_state());
    assert_eq!(*rel_a.title(), b"Label A Single".to_string());
    assert_eq!(*rel_b.title(), b"Label B Single".to_string());

    // Both ids re-derive from the SAME registry id (only the nonce
    // differs) — direct proof both releases are parented to the one shared
    // registry, not to two different namespaces.
    assert_eq!(
        registry.derive_target_release_id(vector[recording_id], vector[10000u64], NONCE_A),
        rel_a.id(),
    );
    assert_eq!(
        registry.derive_target_release_id(vector[recording_id], vector[10000u64], NONCE_B),
        rel_b.id(),
    );

    test_scenario::return_shared(registry);
    test_scenario::return_shared(rel_a);
    test_scenario::return_shared(rel_b);

    destroy(rec_cap);
    scenario.end();
}

// === Events ===

/// Package initialization creates and shares the canonical registry, emitting
/// `ReleaseRegistryCreatedEvent` with its id.
#[test]
fun init_emits_created_event_for_canonical_registry() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    release_registry::init_for_testing(scenario.ctx());

    let mut events = event::events_by_type<release_registry::ReleaseRegistryCreatedEvent>();
    assert_eq!(events.length(), 1);
    let (event_registry_id, created_by) =
        release_registry::release_registry_created_event_fields(&events.pop_back());
    assert_eq!(created_by, SONGWRITER);

    scenario.next_tx(SONGWRITER);
    let registry = scenario.take_shared<ReleaseRegistry>();
    assert_eq!(registry.id(), event_registry_id);
    test_scenario::return_shared(registry);

    scenario.end();
}
