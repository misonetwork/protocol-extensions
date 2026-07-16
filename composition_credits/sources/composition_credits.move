// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// First-party credits extension for compositions.
///
/// Attribution (writing credits) is display-oriented and varies across
/// platforms, so it lives here as a dynamic field on the composition rather than
/// in immutable core. The data is attached under `ExtensionKey()` via the
/// composition's cap-gated `uid_mut`, so every mutation is authorized by the
/// composition's admin and credits survive into any lifecycle state (they may be
/// attached before or after the composition is published).
///
/// This is Miso's canonical credits standard; because it is an extension, other
/// parties may publish their own composition-credits standard against the same
/// `Composition`. Credits are NOT read by the economics — they are attribution.
module composition_credits::composition_credits;

use composition_credits::composition_party_role::CompositionPartyRole;
use miso::composition::{Composition, CompositionAdminCap};
use miso_credit::credit::Credit;
use partyos::party::Party;
use sui::dynamic_field as df;
use sui::vec_map::{Self, VecMap};

// === Constants ===

/// Minimum number of roles a credit must have.
const MIN_ROLES_PER_CREDIT: u64 = 1;
/// Maximum number of roles a credit can have.
const MAX_ROLES_PER_CREDIT: u64 = 5;
/// Maximum number of credits allowed on a composition.
const MAX_CREDITS: u64 = 50;

// === Errors ===

// Validation errors (20-29)
/// Credit must have at least one role.
const EMinRolesNotMet: u64 = 20;

// Constraint errors (30-39)
/// Credit has too many roles.
const EExceedsMaxRoles: u64 = 30;
/// Composition has too many credits.
const EMaxCreditsExceeded: u64 = 32;

// Conflict errors (40-49)
/// Party already has a credit on this composition.
const EPartyAlreadyCredited: u64 = 40;

// Reference errors (50-59)
/// No credits record is attached to this composition.
const ENoCredits: u64 = 50;
/// Party is not credited on the composition.
const EPartyNotCredited: u64 = 52;

// === Dynamic field key + value ===

/// Dynamic-field key — one canonical credits record per composition.
public struct ExtensionKey() has copy, drop, store;

/// The per-composition attribution record, stored as a dynamic field on the
/// composition's UID under `ExtensionKey()`.
public struct CompositionCredits has store {
    /// Map of party IDs to their credit (display name + roles).
    credits: VecMap<ID, Credit<CompositionPartyRole>>,
}

// === Write API ===

/// Adds a credit for a party on the composition, lazily creating the credits
/// record on first use. Each credit must have 1-5 roles, and a party may hold at
/// most one credit. Requires the composition's admin capability.
public fun add_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    party: &Party,
    credit: Credit<CompositionPartyRole>,
) {
    assert!(credit.roles().length() >= MIN_ROLES_PER_CREDIT, EMinRolesNotMet);
    assert!(credit.roles().length() <= MAX_ROLES_PER_CREDIT, EExceedsMaxRoles);

    let party_id = party.id();
    let cc = borrow_mut_or_init(self.uid_mut(cap));
    assert!(cc.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
    assert!(!cc.credits.contains(&party_id), EPartyAlreadyCredited);
    cc.credits.insert(party_id, credit);
}

/// Removes a party's credit. Requires the composition's admin capability.
public fun remove_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    party_id: ID,
) {
    let cc = borrow_mut(self.uid_mut(cap));
    assert!(cc.credits.contains(&party_id), EPartyNotCredited);
    let (_, _) = cc.credits.remove(&party_id);
}

// === Public View Functions ===

/// Returns whether a credits record has been attached to this composition yet.
public fun has_credits<CompositionShare>(self: &Composition<CompositionShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// Returns the party-to-credit map. Aborts if no credits are attached.
public fun credits<CompositionShare>(
    self: &Composition<CompositionShare>,
): &VecMap<ID, Credit<CompositionPartyRole>> {
    &borrow(self.uid()).credits
}

// === Private Functions ===

fun borrow(uid: &UID): &CompositionCredits {
    assert!(df::exists(uid, ExtensionKey()), ENoCredits);
    df::borrow(uid, ExtensionKey())
}

fun borrow_mut(uid: &mut UID): &mut CompositionCredits {
    assert!(df::exists(uid, ExtensionKey()), ENoCredits);
    df::borrow_mut(uid, ExtensionKey())
}

fun borrow_mut_or_init(uid: &mut UID): &mut CompositionCredits {
    if (!df::exists(uid, ExtensionKey())) {
        df::add(
            uid,
            ExtensionKey(),
            CompositionCredits {
                credits: vec_map::empty(),
            },
        );
    };
    df::borrow_mut(uid, ExtensionKey())
}
