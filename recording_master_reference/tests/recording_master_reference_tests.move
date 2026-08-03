// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_master_reference::recording_master_reference_tests;

use miso::recording;
use ori::walrus_data;
use recording_master_reference::recording_master_reference as mref;
use std::unit_test::{assert_eq, destroy};
use sui::event;

// A recording's `RecordingShare` type uniquely identifies it, so
// `RecordingAdminCap<RecordingShare>` is bound to its recording by type and
// `recording::uid_mut` performs no runtime check. A wrong-cap test is therefore
// not expressible here — the call would fail to compile rather than abort.
public struct REC {}
public struct COMP {}
public struct OTHER_REC {}

// Mirrors `ori::walrus_data::ENotBlob`, which rejects a quilt patch.
const ENotBlob: u64 = 0;

fun new_rec(ctx: &mut TxContext): (
    recording::Recording<REC, COMP>,
    recording::RecordingAdminCap<REC>,
) {
    recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx)
}

#[test]
fun set_read_replace_unset_lifecycle() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);

    assert!(!mref::has_master_reference(&rec));

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(111));
    assert!(mref::has_master_reference(&rec));
    assert_eq!(mref::master_reference(&rec).blob_id(), 111);

    // Replacing points at the new blob — a recording has one master, not a list.
    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(222));
    assert_eq!(mref::master_reference(&rec).blob_id(), 222);

    mref::unset_master_reference(&mut rec, &cap);
    assert!(!mref::has_master_reference(&rec));

    // Unset is idempotent.
    mref::unset_master_reference(&mut rec, &cap);
    assert!(!mref::has_master_reference(&rec));

    destroy(rec);
    destroy(cap);
}

/// A sealed master is the expected shape once access control lands, and the
/// reference must carry it unchanged.
#[test]
fun encrypted_blob_is_accepted_and_keeps_its_dek() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_encrypted_blob(333, b"dek"));

    let r = mref::master_reference(&rec);
    assert!(r.is_encrypted());
    assert_eq!(r.blob_id(), 333);
    assert_eq!(*r.sealed_dek(), b"dek");

    destroy(rec);
    destroy(cap);
}

/// Replacing an encrypted reference with a plain one must not leave the old
/// sealed state behind — the whole value is swapped, not merged.
#[test]
fun replacing_encrypted_with_plain_clears_encryption() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_encrypted_blob(1, b"dek"));
    assert!(mref::master_reference(&rec).is_encrypted());

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(2));
    assert!(!mref::master_reference(&rec).is_encrypted());
    assert_eq!(mref::master_reference(&rec).blob_id(), 2);

    destroy(rec);
    destroy(cap);
}

#[test]
fun references_are_per_recording() {
    let ctx = &mut tx_context::dummy();
    let (mut a, a_cap) = new_rec(ctx);
    let (b, b_cap) = recording::new_for_testing<OTHER_REC, COMP>(b"Take 2".to_string(), ctx);

    mref::set_master_reference(&mut a, &a_cap, walrus_data::new_blob(9));

    assert!(mref::has_master_reference(&a));
    assert!(!mref::has_master_reference(&b));

    destroy(a); destroy(a_cap); destroy(b); destroy(b_cap);
}

#[test]
fun set_emits_the_recording() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);
    let rec_id = object::id(&rec);

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(7));

    let events = event::events_by_type<mref::MasterReferenceSetEvent>();
    assert_eq!(events.length(), 1);
    assert_eq!(mref::set_event_recording_id(&events[0]), rec_id);

    destroy(rec);
    destroy(cap);
}

#[test]
fun unset_emits_only_when_something_was_removed() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);
    let rec_id = object::id(&rec);

    // Nothing attached — a no-op must stay silent.
    mref::unset_master_reference(&mut rec, &cap);
    assert_eq!(event::events_by_type<mref::MasterReferenceUnsetEvent>().length(), 0);

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(5));
    mref::unset_master_reference(&mut rec, &cap);

    let events = event::events_by_type<mref::MasterReferenceUnsetEvent>();
    assert_eq!(events.length(), 1);
    assert_eq!(mref::unset_event_recording_id(&events[0]), rec_id);

    destroy(rec);
    destroy(cap);
}

/// The migration this package is built to end in: the reference goes away, and
/// the recording is left clean for the attested master to take over.
#[test]
fun unset_leaves_no_trace_for_the_attested_path() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);

    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(42));
    mref::unset_master_reference(&mut rec, &cap);

    assert!(!mref::has_master_reference(&rec));

    // And re-attaching afterwards still works, so removal is not one-way.
    mref::set_master_reference(&mut rec, &cap, walrus_data::new_blob(43));
    assert_eq!(mref::master_reference(&rec).blob_id(), 43);

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = mref::ENoMasterReference)]
fun master_reference_aborts_when_unset() {
    let ctx = &mut tx_context::dummy();
    let (rec, cap) = new_rec(ctx);
    let _ = mref::master_reference(&rec);
    destroy(rec);
    destroy(cap);
}

/// A master is fetched on its own; batching it into a quilt would make its
/// identity depend on what it was stored alongside.
#[test, expected_failure(abort_code = ENotBlob, location = ori::walrus_data)]
fun quilt_patch_is_rejected() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_rec(ctx);
    mref::set_master_reference(&mut rec, &cap, walrus_data::new_quilt_patch(1, 1, 0, 1));
    destroy(rec);
    destroy(cap);
}
