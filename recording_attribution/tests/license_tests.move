// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_attribution::license_tests;

use miso::recording::{Self, Recording, RecordingAdminCap};
use recording_attribution::license;
use std::unit_test::{assert_eq, destroy};
use sui::vec_set;

public struct TEST_SHARE() has drop;
/// Parent-composition identity for the test recording (phantom; the license
/// never reads it).
public struct COMPOSITION() has drop;

// === Helpers ===

fun new_recording(
    ctx: &mut TxContext,
): (Recording<TEST_SHARE, COMPOSITION>, RecordingAdminCap<TEST_SHARE>) {
    recording::new_for_testing<TEST_SHARE, COMPOSITION>(
        b"Source Recording".to_string(),
        ctx,
    )
}

fun scopes(raw: vector<vector<u8>>): vector<std::string::String> {
    raw.map!(|s| s.to_string())
}

// === Tests ===

#[test]
fun test_attach_and_query() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);
    assert!(!license::is_attached(&rec));
    assert!(!license::grants(&rec, &b"train".to_string())); // absence is denial

    license::attach(&mut rec, &cap, scopes(vector[b"train", b"generate"]));

    assert!(license::is_attached(&rec));
    assert!(license::grants(&rec, &b"train".to_string()));
    assert!(license::grants(&rec, &b"generate".to_string()));
    assert!(!license::grants(&rec, &b"voice-clone".to_string()));
    assert!(license::grants_all(&rec, &vec_set::from_keys(scopes(vector[b"train", b"generate"]))));
    assert!(!license::grants_all(&rec, &vec_set::from_keys(scopes(vector[b"train", b"voice-clone"]))));
    assert_eq!(license::scopes(&rec).length(), 2);

    destroy(rec);
    destroy(cap);
}

#[test]
/// Empty scopes = explicit opt-out: attached, but grants nothing.
fun test_attach_empty_scopes_is_explicit_opt_out() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);

    license::attach(&mut rec, &cap, vector[]);

    assert!(license::is_attached(&rec));
    assert!(!license::grants(&rec, &b"train".to_string()));
    assert!(!license::grants_all(&rec, &vec_set::from_keys(scopes(vector[b"train"]))));

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_revoke_then_reattach() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);

    license::attach(&mut rec, &cap, scopes(vector[b"train"]));
    license::revoke(&mut rec, &cap);
    assert!(!license::is_attached(&rec));
    assert!(!license::grants(&rec, &b"train".to_string()));

    license::attach(&mut rec, &cap, scopes(vector[b"generate"]));
    assert!(license::grants(&rec, &b"generate".to_string()));
    assert!(!license::grants(&rec, &b"train".to_string()));

    destroy(rec);
    destroy(cap);
}

#[test]
#[expected_failure(abort_code = license::ELicenseAlreadyAttached)]
fun test_attach_rejects_double_attach() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);
    license::attach(&mut rec, &cap, scopes(vector[b"train"]));

    license::attach(&mut rec, &cap, scopes(vector[b"generate"]));

    destroy(rec);
    destroy(cap);
}

#[test]
#[expected_failure(abort_code = license::ENoLicenseAttached)]
fun test_revoke_without_license_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);

    license::revoke(&mut rec, &cap);

    destroy(rec);
    destroy(cap);
}

#[test]
#[expected_failure(abort_code = license::EInvalidScope)]
/// Uppercase scopes are rejected — canonical form keeps the subset check
/// in edge creation from being defeated by case variants.
fun test_attach_rejects_uppercase_scope() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);

    license::attach(&mut rec, &cap, scopes(vector[b"Train"]));

    destroy(rec);
    destroy(cap);
}

#[test]
#[expected_failure(abort_code = license::EInvalidScope)]
fun test_attach_rejects_empty_scope_string() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);

    license::attach(&mut rec, &cap, scopes(vector[b""]));

    destroy(rec);
    destroy(cap);
}

#[test]
#[expected_failure(abort_code = license::EInvalidScope)]
fun test_attach_rejects_overlong_scope() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);
    let long = std::string::utf8(vector::tabulate!(65, |_| 0x61));

    license::attach(&mut rec, &cap, vector[long]);

    destroy(rec);
    destroy(cap);
}

#[test]
#[expected_failure(abort_code = license::ETooManyScopes)]
fun test_attach_rejects_too_many_scopes() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_recording(ctx);
    // 17 distinct single-letter scopes (a, b, c, ...) against MAX_SCOPES = 16.
    let many = vector::tabulate!(17, |i| std::string::utf8(vector[0x61 + (i as u8)]));

    license::attach(&mut rec, &cap, many);

    destroy(rec);
    destroy(cap);
}
