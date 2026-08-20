// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The recommended canonical parent namespace for `miso::release::new`.
///
/// `miso::release::new` takes `parent: &mut UID` and derives every release's
/// id from `(parent, digest)`: core is deliberately parent-agnostic and
/// implements no coordination policy of its own (see the "Consent scope"
/// section of `miso::release`'s module doc). This package supplies the one
/// recommended parent — a shared, permissionless, undeletable `UID` — and is
/// deliberately the *only* policy it implements: it neither gates who may
/// assemble a release through it nor interprets what a `Track` means.
///
/// ### One instance, ever
///
/// The module exposes no constructor: the only `ReleaseRegistry` that can
/// ever exist is the canonical one created and shared by package
/// initialization. "The registry" is therefore unambiguous on-chain — the
/// type itself names the namespace, not a config convention. Every
/// `new_release` takes `&mut` on that one shared object, so release creation
/// through it serializes per checkpoint; the ceiling is accepted — releases
/// are rare events. Alternative namespaces are still possible, but they live
/// in other packages: core is parent-agnostic, and any object exposing a
/// `&mut UID` (a release escrow, for instance) can parent its own releases;
/// ids derived under different parents never collide, by construction of
/// `derive_address`.
///
/// ### Liveness
///
/// The canonical instance is shared at publish, and this module exposes no
/// delete function and no `uid_mut`: its only capability is being a
/// derivation parent. That undeletability is a consent guarantee, not an
/// accident — a `Track`'s `target_release_id` commits to this namespace's
/// liveness (see `miso::release`'s module doc), and a deletable parent would
/// strand every track and offer that ever targeted it. Keeping the surface to
/// exactly one capability is what makes that guarantee durable: there is
/// nothing else here to reason about.
///
/// ### Permissionless
///
/// No capability gates `new_release`: anyone holding a fully-formed
/// `vector<Track>` may assemble and claim a release through this registry.
/// That is not a gap — consent already lives in the `Track`s themselves, each
/// one minted by its recording's admin via cap-gated `miso::track::new`
/// against this exact digest. Assembly is bookkeeping over consent already
/// given, not a second authorization step.
module release_registry::release_registry;

use miso::release::{Self, Release, ReleaseAdminCap};
use miso::track::Track;
use std::string::String;
use sui::event::emit;

// === Structs ===

/// A shared derivation-parent namespace for `miso::release::new`. Holds no
/// state beyond its own identity — the `UID` itself is the entire product.
public struct ReleaseRegistry has key {
    id: UID,
}

// === Events ===

/// Emitted once, when package initialization creates the canonical
/// `ReleaseRegistry`, so indexers and clients can discover its id from the
/// publish transaction.
public struct ReleaseRegistryCreatedEvent has copy, drop {
    registry_id: ID,
    created_by: address,
}

/// Module initializer. Creates and shares the canonical `ReleaseRegistry` —
/// the recommended default parent for `miso::release::new`.
fun init(ctx: &mut TxContext) {
    let registry = ReleaseRegistry { id: object::new(ctx) };

    emit(ReleaseRegistryCreatedEvent {
        registry_id: registry.id(),
        created_by: ctx.sender(),
    });

    transfer::share_object(registry);
}

// === Public Functions ===

/// Assembles a release by delegating to `miso::release::new` with this
/// registry as parent. Returns the `(Release, ReleaseAdminCap)` pair rather
/// than transferring or sharing either: the release is not on-chain-final
/// until `release::publish` consumes it by value — typically later in the
/// same PTB — and where the cap ends up is the caller's decision, not this
/// function's.
public fun new_release(
    self: &mut ReleaseRegistry,
    title: String,
    tracks: vector<Track>,
    nonce: u256,
): (Release, ReleaseAdminCap) {
    release::new(title, tracks, nonce, &mut self.id)
}

/// Derives the release id `new_release` would produce for the given inputs
/// under this registry, without creating anything. Delegates to
/// `miso::release::derive_target_release_id` with this registry's own id as
/// parent.
public fun derive_target_release_id(
    self: &ReleaseRegistry,
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    nonce: u256,
): ID {
    release::derive_target_release_id(recording_ids, track_split_values, nonce, self.id.to_inner())
}

/// Returns the registry's object id — the derivation parent that
/// `derive_target_release_id` and `new_release` both commit to.
public fun id(self: &ReleaseRegistry): ID {
    self.id.to_inner()
}

// === Test Functions ===

/// Runs the real module initializer (creates and shares the canonical
/// `ReleaseRegistry`).
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

/// Creates a bare, unshared registry as a stand-in derivation parent. Tests
/// only — the production module exposes no constructor.
#[test_only]
public fun new_for_testing(ctx: &mut TxContext): ReleaseRegistry {
    ReleaseRegistry { id: object::new(ctx) }
}

#[test_only]
public fun release_registry_created_event_fields(e: &ReleaseRegistryCreatedEvent): (ID, address) {
    (e.registry_id, e.created_by)
}
