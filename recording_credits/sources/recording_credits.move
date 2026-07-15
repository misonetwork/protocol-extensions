// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// First-party credits extension for recordings.
///
/// Attribution (credits + primary/featured artists) is display-oriented and
/// varies across platforms, so it lives here as a dynamic field on the recording
/// rather than in immutable core. The data is attached under `RecordingCreditsKey()` via
/// the recording's cap-gated `uid_mut`, so every mutation is authorized by the
/// recording's admin and credits survive into any lifecycle state (they may be
/// attached before or after the recording is published).
///
/// This is Miso's canonical credits standard; because it is an extension, other
/// parties may publish their own recording-credits standard against the same
/// `Recording`. Credits are NOT read by the economics — they are attribution.
module recording_credits::recording_credits;

use miso::recording::{Recording, RecordingAdminCap};
use credit::credit::Credit;
use partyos::party::Party;
use recording_credits::recording_party_role::RecordingPartyRole;
use sui::dynamic_field as df;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// === Constants ===

/// Minimum number of roles a credit must have.
const MIN_ROLES_PER_CREDIT: u64 = 1;
/// Maximum number of roles a credit can have.
const MAX_ROLES_PER_CREDIT: u64 = 10;
/// Maximum number of credits allowed on a recording.
const MAX_CREDITS: u64 = 150;
/// Maximum number of primary artists allowed on a recording.
const MAX_PRIMARY_ARTISTS: u64 = 20;
/// Maximum number of featured artists allowed on a recording.
const MAX_FEATURED_ARTISTS: u64 = 50;

// === Errors ===

// Validation errors (20-29)
/// Credit must have at least one role.
const EMinRolesNotMet: u64 = 20;

// Constraint errors (30-39)
/// Credit has too many roles.
const EExceedsMaxRoles: u64 = 30;
/// Recording has too many credits.
const EMaxCreditsExceeded: u64 = 32;
/// Recording has too many primary artists.
const EMaxPrimaryArtistsExceeded: u64 = 34;
/// Recording has too many featured artists.
const EMaxFeaturedArtistsExceeded: u64 = 35;

// Conflict errors (40-49)
/// Party already has a credit on this recording.
const EPartyAlreadyCredited: u64 = 40;
/// Party is already a primary artist.
const EAlreadyPrimaryArtist: u64 = 41;
/// Party is already a featured artist.
const EAlreadyFeaturedArtist: u64 = 42;

// Reference errors (50-59)
/// No credits record is attached to this recording.
const ENoCredits: u64 = 50;
/// Party is not credited on the recording.
const EPartyNotCredited: u64 = 52;

// === Dynamic field key + value ===

/// Dynamic-field key — one canonical credits record per recording.
public struct RecordingCreditsKey() has copy, drop, store;

/// The per-recording attribution record, stored as a dynamic field on the
/// recording's UID under `RecordingCreditsKey()`.
public struct RecordingCredits has store {
    /// Map of party IDs to their credit (display name + roles).
    credits: VecMap<ID, Credit<RecordingPartyRole>>,
    /// IDs of the primary artists. Always a subset of `credits`.
    primary_artist_ids: VecSet<ID>,
    /// IDs of the featured artists. Always a subset of `credits`.
    featured_artist_ids: VecSet<ID>,
}

// === Write API ===

/// Adds a credit for a party on the recording, lazily creating the credits
/// record on first use. Each credit must have 1-10 roles, and a party may hold
/// at most one credit. Requires the recording's admin capability.
public fun add_credit<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party: &Party,
    credit: Credit<RecordingPartyRole>,
) {
    assert!(credit.roles().length() >= MIN_ROLES_PER_CREDIT, EMinRolesNotMet);
    assert!(credit.roles().length() <= MAX_ROLES_PER_CREDIT, EExceedsMaxRoles);

    let party_id = party.id();
    let rc = borrow_mut_or_init(self.uid_mut(cap));
    assert!(rc.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
    assert!(!rc.credits.contains(&party_id), EPartyAlreadyCredited);
    rc.credits.insert(party_id, credit);
}

/// Removes a party's credit. Also drops them from the primary/featured sets,
/// preserving the invariant that those are subsets of the credited parties.
/// Requires the recording's admin capability.
public fun remove_credit<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let rc = borrow_mut(self.uid_mut(cap));
    assert!(rc.credits.contains(&party_id), EPartyNotCredited);
    let (_, _) = rc.credits.remove(&party_id);
    if (rc.primary_artist_ids.contains(&party_id)) rc.primary_artist_ids.remove(&party_id);
    if (rc.featured_artist_ids.contains(&party_id)) rc.featured_artist_ids.remove(&party_id);
}

/// Designates an already-credited party as a primary artist. The party must be
/// credited and not already a primary or featured artist.
public fun add_primary_artist<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party: &Party,
) {
    let party_id = party.id();
    let rc = borrow_mut(self.uid_mut(cap));
    assert!(rc.primary_artist_ids.length() < MAX_PRIMARY_ARTISTS, EMaxPrimaryArtistsExceeded);
    assert!(rc.credits.contains(&party_id), EPartyNotCredited);
    assert!(!rc.featured_artist_ids.contains(&party_id), EAlreadyFeaturedArtist);
    assert!(!rc.primary_artist_ids.contains(&party_id), EAlreadyPrimaryArtist);
    rc.primary_artist_ids.insert(party_id);
}

/// Removes a party from the primary-artist set (leaves the credit intact).
public fun remove_primary_artist<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let rc = borrow_mut(self.uid_mut(cap));
    assert!(rc.primary_artist_ids.contains(&party_id), EPartyNotCredited);
    rc.primary_artist_ids.remove(&party_id);
}

/// Designates an already-credited party as a featured artist. The party must be
/// credited and not already a primary or featured artist.
public fun add_featured_artist<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party: &Party,
) {
    let party_id = party.id();
    let rc = borrow_mut(self.uid_mut(cap));
    assert!(rc.featured_artist_ids.length() < MAX_FEATURED_ARTISTS, EMaxFeaturedArtistsExceeded);
    assert!(rc.credits.contains(&party_id), EPartyNotCredited);
    assert!(!rc.primary_artist_ids.contains(&party_id), EAlreadyPrimaryArtist);
    assert!(!rc.featured_artist_ids.contains(&party_id), EAlreadyFeaturedArtist);
    rc.featured_artist_ids.insert(party_id);
}

/// Removes a party from the featured-artist set (leaves the credit intact).
public fun remove_featured_artist<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let rc = borrow_mut(self.uid_mut(cap));
    assert!(rc.featured_artist_ids.contains(&party_id), EPartyNotCredited);
    rc.featured_artist_ids.remove(&party_id);
}

// === Public View Functions ===

/// Returns whether a credits record has been attached to this recording yet.
public fun has_credits<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): bool {
    df::exists(self.uid(), RecordingCreditsKey())
}

/// Returns the party-to-credit map. Aborts if no credits are attached.
public fun credits<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &VecMap<ID, Credit<RecordingPartyRole>> {
    &borrow(self.uid()).credits
}

/// Returns the primary-artist IDs. Aborts if no credits are attached.
public fun primary_artist_ids<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &VecSet<ID> {
    &borrow(self.uid()).primary_artist_ids
}

/// Returns the featured-artist IDs. Aborts if no credits are attached.
public fun featured_artist_ids<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &VecSet<ID> {
    &borrow(self.uid()).featured_artist_ids
}

/// Returns whether the party is a primary artist (false if no credits attached).
public fun is_primary_artist<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
    party_id: ID,
): bool {
    has_credits(self) && borrow(self.uid()).primary_artist_ids.contains(&party_id)
}

/// Returns whether the party is a featured artist (false if no credits attached).
public fun is_featured_artist<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
    party_id: ID,
): bool {
    has_credits(self) && borrow(self.uid()).featured_artist_ids.contains(&party_id)
}

// === Private Functions ===

fun borrow(uid: &UID): &RecordingCredits {
    assert!(df::exists(uid, RecordingCreditsKey()), ENoCredits);
    df::borrow(uid, RecordingCreditsKey())
}

fun borrow_mut(uid: &mut UID): &mut RecordingCredits {
    assert!(df::exists(uid, RecordingCreditsKey()), ENoCredits);
    df::borrow_mut(uid, RecordingCreditsKey())
}

fun borrow_mut_or_init(uid: &mut UID): &mut RecordingCredits {
    if (!df::exists(uid, RecordingCreditsKey())) {
        df::add(
            uid,
            RecordingCreditsKey(),
            RecordingCredits {
                credits: vec_map::empty(),
                primary_artist_ids: vec_set::empty(),
                featured_artist_ids: vec_set::empty(),
            },
        );
    };
    df::borrow_mut(uid, RecordingCreditsKey())
}
