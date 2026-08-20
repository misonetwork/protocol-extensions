// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Pure derivation-math and abort-path coverage for `release_registry`.
/// Both tests here run under bare `tx_context::dummy()`: neither shared
/// objects nor cross-actor ownership is involved — only
/// `derive_target_release_id`'s pure arithmetic over synthetic ids and
/// `new_release`'s duplicate-digest abort, which is a property of the
/// digest math, not of who calls it. `test_scenario` mechanics would add
/// nothing here. The full production flow — the canonical init-shared
/// registry, real senders across transaction boundaries, publish+share — is
/// covered separately in `release_registry_e2e_tests`.
#[test_only]
module release_registry::release_registry_tests;

use miso::test_helpers;
use miso::track;
use release_registry::release_registry;
use std::unit_test::{assert_eq, destroy};

const NONCE: u256 = 42;

// === Namespace independence ===

/// Distinct parents derive distinct ids for identical digest inputs, and the
/// same digest may be claimed once under each without interference. In
/// production only the canonical registry exists; two bare test instances
/// stand in for "different parents" generally (the property core guarantees
/// for any parent, e.g. a release escrow alongside the registry).
#[test]
fun distinct_parents_derive_distinct_ids_and_both_are_claimable() {
    let ctx = &mut tx_context::dummy();
    let mut registry_a = release_registry::new_for_testing(ctx);
    let mut registry_b = release_registry::new_for_testing(ctx);
    assert!(registry_a.id() != registry_b.id());

    let composition_id = test_helpers::fake_id(ctx);
    let recording_id = test_helpers::fake_id(ctx);
    let recording_ids = vector[recording_id];
    let track_splits = vector[10000u64];

    let id_a = registry_a.derive_target_release_id(recording_ids, track_splits, NONCE);
    let id_b = registry_b.derive_target_release_id(recording_ids, track_splits, NONCE);
    assert!(id_a != id_b);

    let (rel_a, cap_a) = registry_a.new_release(
        b"Via A".to_string(),
        vector[track::new_for_testing(composition_id, recording_id, id_a, 10000u16)],
        NONCE,
    );
    let (rel_b, cap_b) = registry_b.new_release(
        b"Via B".to_string(),
        vector[track::new_for_testing(composition_id, recording_id, id_b, 10000u16)],
        NONCE,
    );
    assert_eq!(rel_a.id(), id_a);
    assert_eq!(rel_b.id(), id_b);

    destroy(rel_a);
    destroy(cap_a);
    destroy(rel_b);
    destroy(cap_b);
    destroy(registry_a);
    destroy(registry_b);
}

// === Duplicate claim ===

/// The same digest (recording set + splits + nonce) can only ever be claimed
/// once through a given registry — the second `new_release` aborts inside
/// `sui::derived_object` on the duplicate claim.
#[test, expected_failure]
fun new_release_aborts_on_duplicate_digest_claim() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release_registry::new_for_testing(ctx);
    let composition_id = test_helpers::fake_id(ctx);
    let recording_id = test_helpers::fake_id(ctx);
    let placeholder_target_id = test_helpers::fake_id(ctx);

    let (rel1, cap1) = registry.new_release(
        b"First".to_string(),
        vector[
            track::new_for_testing(composition_id, recording_id, placeholder_target_id, 10000u16),
        ],
        7u256,
    );
    // Identical recording id, splits, and nonce under the same registry:
    // identical digest, identical parent, identical claimed address.
    let (rel2, cap2) = registry.new_release(
        b"Second".to_string(),
        vector[
            track::new_for_testing(composition_id, recording_id, placeholder_target_id, 10000u16),
        ],
        7u256,
    );
    destroy(rel1);
    destroy(cap1);
    destroy(rel2);
    destroy(cap2);
    destroy(registry);
}
