// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Seal decryption policy for a recording's encrypted masters — a first-party
/// miso extension.
///
/// An encrypted master's AES data-encryption key is Seal-sealed under **this
/// package's** namespace with identity `[recording_id ‖ pcm_digest]`. Seal key
/// servers release the key by dry-running the `seal_approve*` entry points
/// below, which check that the requester is a principal the rights holder has
/// granted on the recording.
///
/// Grants are managed by the `meigi` primitive, scoped to this policy's
/// `Witness`, and stored on the recording's UID via the cap-gated `uid_mut` —
/// so granting and revoking is the rights holder's consent, revocable at any
/// time. A principal is either a raw address or a SuiNS name: a name grant
/// authorizes whatever address the name currently targets (pinned to the
/// name's registration NFT, so a lapsed-and-re-registered name fails closed).
///
/// The policy intentionally does not check that a master is attached under
/// the identity's digest: the sealed DEK only decrypts the blob it was
/// produced for, so attachment adds nothing — and the policy stays free of
/// any dependency on `recording_master` or a concrete master type.
module recording_seal_acl::acl;

use meigi::meigi;
use miso::recording::{Recording, RecordingAdminCap};
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::bcs;
use suins::suins::SuiNS;

// === Structs ===

/// Scopes this policy's grants in meigi. Only this package can produce it, so
/// only this package's grant/revoke functions can write the scope.
public struct Witness() has drop;

// === Errors ===

// Seal-policy errors (50-59)
/// The Seal id is not bound to this recording.
const EWrongRecording: u64 = 50;
/// The Seal id has trailing bytes.
const EMalformedId: u64 = 51;
/// The sender is not an authorized principal for this recording.
const ENoAccess: u64 = 52;

// === Grants ===

/// Grants `grantee` the right to decrypt this recording's masters. Gated by
/// the recording's admin capability — the rights holder's consent.
public fun grant_address<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    grantee: address,
) {
    meigi::grant_address(self.uid_mut(cap), Witness(), grantee)
}

/// Revokes an address grant. Effective for all future key requests.
public fun revoke_address<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    grantee: address,
) {
    meigi::revoke_address(self.uid_mut(cap), Witness(), grantee)
}

/// Grants the SuiNS name `name` (e.g. `delivery.miso.sui`) the right to
/// decrypt this recording's masters. The authorized address is whatever the
/// name targets at key-request time, pinned to the name's current
/// registration NFT.
public fun grant_name<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    name: String,
    suins: &SuiNS,
) {
    meigi::grant_name(self.uid_mut(cap), Witness(), name, suins)
}

/// Revokes a name grant. Effective for all future key requests.
public fun revoke_name<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    name: String,
) {
    meigi::revoke_name(self.uid_mut(cap), Witness(), name)
}

// === Seal policy ===

/// Approves a key request from a directly granted address.
/// Identity: `[recording_id ‖ pcm_digest]`.
entry fun seal_approve<RecordingShare, CompositionShare>(
    id: vector<u8>,
    recording: &Recording<RecordingShare, CompositionShare>,
    ctx: &TxContext,
) {
    assert_bound(id, recording);
    assert!(meigi::is_address_authorized(recording.uid(), scope(), ctx.sender()), ENoAccess);
}

/// Approves a key request from the current target of a granted SuiNS name.
/// The requester passes the `name` they claim; the policy checks the grant
/// exists, the pinned registration still backs the name, and the name
/// currently targets the sender. Identity: `[recording_id ‖ pcm_digest]`.
entry fun seal_approve_name<RecordingShare, CompositionShare>(
    id: vector<u8>,
    recording: &Recording<RecordingShare, CompositionShare>,
    name: String,
    suins: &SuiNS,
    ctx: &TxContext,
) {
    assert_bound(id, recording);
    assert!(
        meigi::is_name_authorized(recording.uid(), scope(), name, suins, ctx.sender()),
        ENoAccess,
    );
}

// === Views ===

/// The meigi scope this policy stores grants under — the defining `TypeName`
/// of its `Witness`. For clients computing dynamic-field ids or reading
/// grants through meigi directly.
public fun scope(): TypeName {
    with_defining_ids<Witness>()
}

/// Whether `sender` holds a direct address grant on the recording.
public fun is_address_authorized<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
    sender: address,
): bool {
    meigi::is_address_authorized(recording.uid(), scope(), sender)
}

/// Whether `sender` is the current target of a granted SuiNS name.
public fun is_name_authorized<RecordingShare, CompositionShare>(
    recording: &Recording<RecordingShare, CompositionShare>,
    name: String,
    suins: &SuiNS,
    sender: address,
): bool {
    meigi::is_name_authorized(recording.uid(), scope(), name, suins, sender)
}

// === Internal ===

/// Asserts the Seal identity `[recording_id ‖ pcm_digest]` is bound to this
/// recording. The digest is peeled but not checked against attached content —
/// it scopes the identity (and thus the derived key) per master.
fun assert_bound<RecordingShare, CompositionShare>(
    id: vector<u8>,
    recording: &Recording<RecordingShare, CompositionShare>,
) {
    let mut reader = bcs::new(id);
    assert!(reader.peel_address() == recording.id().to_address(), EWrongRecording);
    let _digest = reader.peel_vec_u8();
    assert!(reader.into_remainder_bytes().is_empty(), EMalformedId);
}
