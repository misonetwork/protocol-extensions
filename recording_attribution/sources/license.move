// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Opt-in generative-use license for a `Recording`.
///
/// A rights holder publishes the scopes (e.g. `train`, `generate`) they
/// grant for generative use of their recording. The license lives as a
/// dynamic field under the recording's UID: writes are gated by the
/// recording's admin cap, reads are public. `recording_attribution::
/// attribution` checks it at edge creation — no attribution edge can exist
/// claiming a scope the source never granted.
///
/// Semantics:
/// - **Absence is denial** (opt-in model): no license → `grants_all` is
///   false → no edge can be created for this source.
/// - **Empty scopes is an explicit opt-out** — a distinct, timestamped
///   refusal that screening layers can cite, stronger than silence.
/// - **Revocation is creation-time only**: revoking blocks *new* edges;
///   existing edges are immutable and keep routing. A license can be
///   withdrawn but not rugged.
///
/// Scope identifiers are canonical by construction — lowercase ASCII
/// (`a-z`, `0-9`, `-`, `_`), bounded count and length — because the subset
/// check in edge creation does real enforcement and must not be defeated
/// by case or encoding mismatches. Provider-specific attestations (e.g.
/// enclave-verified metadata from an attribution provider) can layer on as
/// separate packages without touching this one.
///
/// Distinct from `recording_license` (the Seal decryption allowlist for
/// encrypted masters): that gates who may *read* the master; this gates
/// what generative *uses* are licensed. The two compose.
module recording_attribution::license;

use miso::recording::{Recording, RecordingAdminCap};
use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set::{Self, VecSet};

// === Structs ===

public struct RecordingAttributionLicense has drop, store {
    /// Granted scope identifiers. Empty = explicit opt-out.
    scopes: VecSet<String>,
}

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct LicenseAttachedEvent<phantom RecordingShare> has copy, drop {
    scopes: VecSet<String>,
}

public struct LicenseRevokedEvent<phantom RecordingShare> has copy, drop {}

// === Constants ===

/// Maximum number of scopes a license can grant.
const MAX_SCOPES: u64 = 16;
/// Maximum byte length of a scope identifier.
const MAX_SCOPE_LENGTH: u64 = 64;

// === Errors ===

/// A license is already attached to this recording.
const ELicenseAlreadyAttached: u64 = 0;
/// No license is attached to this recording.
const ENoLicenseAttached: u64 = 1;
/// Scope count exceeds MAX_SCOPES.
const ETooManyScopes: u64 = 2;
/// Scope must be 1-64 bytes of lowercase ASCII (`a-z`, `0-9`, `-`, `_`).
const EInvalidScope: u64 = 3;

// === Public Functions ===

/// Attach a license to the recording. Cap-gated — this is the rights
/// holder's opt-in act. Aborts if one is already attached (revoke first to
/// change terms, so every change is a visible two-step with an event trail).
public fun attach<RecordingShare, CompositionShare>(
    recording: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    scopes: vector<String>,
) {
    assert!(scopes.length() <= MAX_SCOPES, ETooManyScopes);
    scopes.do_ref!(|scope| assert_valid_scope(scope));
    let scopes = vec_set::from_keys(scopes); // aborts on duplicates

    let uid = recording.uid_mut(cap);
    assert!(!df::exists(uid, ExtensionKey()), ELicenseAlreadyAttached);

    emit(LicenseAttachedEvent<RecordingShare> { scopes });

    df::add(uid, ExtensionKey(), RecordingAttributionLicense { scopes });
}

/// Detach the license. Blocks creation of new attribution edges for this
/// source; existing edges are unaffected.
public fun revoke<RecordingShare, CompositionShare>(
    recording: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let uid = recording.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey()), ENoLicenseAttached);

    df::remove<ExtensionKey, RecordingAttributionLicense>(
        uid,
        ExtensionKey(),
    );

    emit(LicenseRevokedEvent<RecordingShare> {});
}

// === Public View Functions ===

/// Whether a license (including an explicit opt-out) is attached.
public fun is_attached<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
): bool {
    df::exists(recording.uid(), ExtensionKey())
}

/// Whether the license grants the given scope. False when no license is
/// attached (absence is denial).
public fun grants<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
    scope: &String,
): bool {
    if (!is_attached(recording)) {
        return false
    };
    borrow(recording).scopes.contains(scope)
}

/// Whether the license grants every scope in the set. False when no
/// license is attached (absence is denial).
public fun grants_all<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
    scopes: &VecSet<String>,
): bool {
    if (!is_attached(recording)) {
        return false
    };
    let license = borrow(recording);
    scopes.keys().all!(|scope| license.scopes.contains(scope))
}

/// The granted scopes. Aborts if no license is attached.
public fun scopes<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
): &VecSet<String> {
    assert!(is_attached(recording), ENoLicenseAttached);
    &borrow(recording).scopes
}

// === Private Functions ===

fun borrow<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
): &RecordingAttributionLicense {
    df::borrow(recording.uid(), ExtensionKey())
}

/// Scope identifiers are enforced canonical so the `grants_all` subset
/// check cannot be defeated by case or encoding variants of the same scope.
fun assert_valid_scope(scope: &String) {
    let bytes = scope.as_bytes();
    let len = bytes.length();
    assert!(len > 0 && len <= MAX_SCOPE_LENGTH, EInvalidScope);
    bytes.do_ref!(|b| {
        let b = *b;
        assert!(
            (b >= 0x61 && b <= 0x7A) // a-z
                || (b >= 0x30 && b <= 0x39) // 0-9
                || b == 0x2D // -
                || b == 0x5F, // _
            EInvalidScope,
        );
    });
}
