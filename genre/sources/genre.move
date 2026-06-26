// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Genre vocabulary for Miso — a curated, deduplicated set of `Genre` objects.
///
/// Genre is a classification, not protocol-verifiable state, so it lives in an
/// extension rather than core. This module owns the **vocabulary**: `Genre`
/// objects created by a `GenreRegistryCap` holder (Miso), derived by canonical
/// name so the set stays deduplicated and canonical (no "hip-hop" vs "Hip Hop"
/// forks).
///
/// Genre *assignment* — classifying a release and its individual tracks — lives
/// in the `release_genre` module. How a recording is presented and classified
/// is a property of the release (the consumer object), not of the recording's
/// objective sound data, so nothing here touches `Recording`.
module genre::genre;

use std::string::{Self, String};
use sui::derived_object::{Self, claim};
use sui::event::emit;

// === Structs ===

/// One-time witness for the genre package.
public struct GENRE has drop {}

/// Shared registry that parents the derived `Genre` objects.
public struct GenreRegistry has key {
    id: UID,
}

/// Capability authorizing creation of new genres. Held by the vocabulary curator.
public struct GenreRegistryCap has key, store {
    id: UID,
}

/// A genre in the canonical vocabulary. Immutable (frozen) once created.
/// Derived from the registry by `GenreKey(name)`, so a given name maps to a
/// single, deterministic object id.
public struct Genre has key {
    id: UID,
    /// Canonical genre name (e.g. "HIP_HOP").
    name: String,
}

// === Derivation keys ===

/// Derivation key for a `Genre`, keyed by its canonical name.
public struct GenreKey(String) has copy, drop, store;

// === Events ===

/// Emitted when a genre is added to the vocabulary.
public struct GenreCreatedEvent has copy, drop {
    genre_id: ID,
    name: String,
}

// === Constants ===

/// Maximum length of a genre name in bytes.
const MAX_NAME_LENGTH: u64 = 64;

// === Errors ===

// Validation errors (20-29)
/// Genre name must not be empty.
const EEmptyName: u64 = 20;
/// Genre name exceeds the maximum length.
const ENameTooLong: u64 = 21;
/// Genre name contains a character other than `A`-`Z` or `_`.
const EInvalidNameChar: u64 = 22;

// === Init ===

fun init(_otw: GENRE, ctx: &mut TxContext) {
    transfer::share_object(GenreRegistry { id: object::new(ctx) });
    transfer::public_transfer(GenreRegistryCap { id: object::new(ctx) }, ctx.sender());
}

// === Vocabulary (curated) ===

/// Creates a new genre in the canonical vocabulary. Cap-gated: only the
/// registry curator can extend the vocabulary. Derived by canonical name, so
/// creating the same name twice aborts (dedup is automatic). The `Genre` is
/// frozen — immutable and globally readable by reference.
public fun new(_: &GenreRegistryCap, registry: &mut GenreRegistry, name: String) {
    assert!(!name.is_empty(), EEmptyName);
    assert!(name.length() <= MAX_NAME_LENGTH, ENameTooLong);
    // Canonical form: uppercase `A`-`Z` and `_` only (e.g. "HIP_HOP"). Keeps the
    // vocabulary uniform so name-derived dedup is meaningful.
    assert!(
        name.as_bytes().all!(|c| (*c >= 0x41 && *c <= 0x5A) || *c == 0x5F),
        EInvalidNameChar,
    );

    // Copy the name for the object field/event before the original is moved
    // into the derivation key.
    let name_copy = string::utf8(*name.as_bytes());
    let genre = Genre {
        id: claim(&mut registry.id, GenreKey(name)),
        name: name_copy,
    };

    emit(GenreCreatedEvent { genre_id: genre.id(), name: *genre.name() });
    transfer::freeze_object(genre);
}

/// Derives the object id a `Genre` with the given name would have, without
/// creating it. Lets clients resolve/check a genre id offline.
public fun derive_genre_id(self: &GenreRegistry, name: String): ID {
    derived_object::derive_address(self.id.to_inner(), GenreKey(name)).to_id()
}

// === Genre views ===

/// Returns the genre's object id.
public fun id(self: &Genre): ID {
    self.id.to_inner()
}

/// Returns the genre's canonical name.
public fun name(self: &Genre): &String {
    &self.name
}

// === Test Only ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(GENRE {}, ctx)
}
