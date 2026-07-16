// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_preview::recording_preview_tests;

use miso::recording;
use ori::walrus_data;
use recording_preview::recording_preview as rp;
use std::unit_test::{assert_eq, destroy};

// Phantom marker types for the share parameters.
public struct REC {}
public struct COMP {}

#[test]
fun set_replace_unset_lifecycle() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, rec_cap) = recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx);

    assert!(!rp::has_preview(&rec));

    rp::set_preview(&mut rec, &rec_cap, walrus_data::new_blob(1));
    assert!(rp::has_preview(&rec));
    assert_eq!(rp::preview(&rec).blob_id(), 1);

    // Setting again replaces the existing preview in place.
    rp::set_preview(&mut rec, &rec_cap, walrus_data::new_blob(2));
    assert_eq!(rp::preview(&rec).blob_id(), 2);

    rp::unset_preview(&mut rec, &rec_cap);
    assert!(!rp::has_preview(&rec));

    // Unset is idempotent.
    rp::unset_preview(&mut rec, &rec_cap);
    assert!(!rp::has_preview(&rec));

    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun encrypted_blob_is_accepted() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, rec_cap) = recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx);

    rp::set_preview(&mut rec, &rec_cap, walrus_data::new_encrypted_blob(3, b"dek"));
    assert!(rp::preview(&rec).is_encrypted());

    destroy(rec);
    destroy(rec_cap);
}

#[test, expected_failure(abort_code = 1, location = recording_preview::recording_preview)]
fun preview_aborts_when_unset() {
    let ctx = &mut tx_context::dummy();
    let (rec, rec_cap) = recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx);

    let _ = rp::preview(&rec);

    destroy(rec);
    destroy(rec_cap);
}

// ENotBlob in ori::walrus_data — quilt patches are not standalone blobs.
#[test, expected_failure(abort_code = 0, location = ori::walrus_data)]
fun set_preview_rejects_quilt_patch() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, rec_cap) = recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx);

    rp::set_preview(&mut rec, &rec_cap, walrus_data::new_quilt_patch(1, 1, 0, 1));

    destroy(rec);
    destroy(rec_cap);
}
