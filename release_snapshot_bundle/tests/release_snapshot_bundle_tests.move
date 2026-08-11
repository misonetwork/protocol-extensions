// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_snapshot_bundle::release_snapshot_bundle_tests;

use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use ori::walrus_data;
use release_snapshot_bundle::release_snapshot_bundle as bundle;
use std::unit_test::{assert_eq, destroy};
use sui::event;

// Mirrored from miso::release::EUnauthorized (private there).
const EUnauthorized: u64 = 0;
// Mirrors ori::walrus_data::ENotBlob, which rejects a quilt patch.
const ENotBlob: u64 = 0;

// A minimal release: one track carrying the full 10,000 BPS split.
fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    let rel_id = test_helpers::fake_id(ctx);
    let r0 = test_helpers::fake_id(ctx);
    let tracks = vector[track::new_for_testing(r0, rel_id, 10000)];
    release::new_for_testing(b"Album".to_string(), tracks, ctx)
}

#[test]
fun set_on_a_fresh_release_attaches_and_reads_back() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);

    assert!(!bundle::has_snapshot_bundle(&rel));

    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(111));

    assert!(bundle::has_snapshot_bundle(&rel));
    assert_eq!(bundle::snapshot_bundle(&rel).blob_id(), 111);

    destroy(rel);
    destroy(cap);
}

#[test]
fun set_emits_the_bundle_and_release() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);

    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(7));

    // With no unset and no replace, this event is the slot's complete history
    // — it must carry the reference itself, not just a pointer to the object.
    let events = event::events_by_type<bundle::SnapshotBundleSetEvent>();
    assert_eq!(events.length(), 1);
    let (release_id, reference) = bundle::set_event_fields(&events[0]);
    assert_eq!(release_id, rel_id);
    assert_eq!(reference, walrus_data::new_blob(7));

    destroy(rel);
    destroy(cap);
}

#[test]
fun bundles_are_per_release() {
    let ctx = &mut tx_context::dummy();
    let (mut a, a_cap) = mk_release(ctx);
    let (b, b_cap) = mk_release(ctx);

    bundle::set_snapshot_bundle(&mut a, &a_cap, walrus_data::new_blob(9));

    assert!(bundle::has_snapshot_bundle(&a));
    assert!(!bundle::has_snapshot_bundle(&b));

    destroy(a);
    destroy(a_cap);
    destroy(b);
    destroy(b_cap);
}

// The write-once guarantee: a set bundle can never be swapped out from under
// a buyer's Record. There is no unset or replace to test — this abort is the
// entire mutation story after the first set.
#[test, expected_failure(abort_code = bundle::EBundleAlreadySet)]
fun second_set_aborts_the_slot_is_write_once() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);

    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(1));
    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_blob(2));
    abort
}

// The cap gate comes before argument validation and the already-set check,
// so a wrong cap aborts in `uid_mut` even when the slot is empty.
#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun set_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, _cap) = mk_release(ctx);
    let (_other_rel, other_cap) = mk_release(ctx);

    bundle::set_snapshot_bundle(&mut rel, &other_cap, walrus_data::new_blob(1));
    abort
}

#[test, expected_failure(abort_code = bundle::ENoSnapshotBundle)]
fun snapshot_bundle_view_without_attachment_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _cap) = mk_release(ctx);

    let _ = bundle::snapshot_bundle(&rel);
    abort
}

/// The bundle is the whole quilt, addressed as one Walrus blob; a quilt patch
/// is a slice of some other quilt and — with no replace — would be a
/// permanently wrong pointer.
#[test, expected_failure(abort_code = ENotBlob, location = ori::walrus_data)]
fun quilt_patch_is_rejected() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);

    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_quilt_patch(1, 1, 0, 1));
    abort
}

/// The outer quilt blob is plaintext by design — the `manifest.json` patch
/// must be readable, encryption is per-patch inside the quilt, and the
/// Seal-wrapped key travels as the `key.seal` patch. An encrypted outer
/// reference would be a permanently wrong pointer.
#[test, expected_failure(abort_code = bundle::EBundleMustBePlaintext)]
fun encrypted_blob_is_rejected() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);

    bundle::set_snapshot_bundle(&mut rel, &cap, walrus_data::new_encrypted_blob(1, b"dek"));
    abort
}
