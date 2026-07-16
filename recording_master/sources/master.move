// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Generic "master" attachment for recordings — a first-party miso extension.
///
/// A master is any `store` value: Miso's `audio::Audio`, a future video or
/// immersive type, anything an ingester produces. This module is deliberately
/// **media-agnostic** — it never references a concrete master type and blesses
/// no ingester. It operates directly on a `Recording`, attaching masters as
/// dynamic fields on the recording's UID.
///
/// ### Trust model
///
/// Masters are namespaced by the **ingester** that produced them. The namespace
/// is the defining `TypeName` of an ingester witness `W`, and `add` derives
/// it *from the witness itself* — so only a package that can produce `W` can
/// write under `W`'s namespace. A consumer reads the masters from the ingester
/// type(s) it trusts and ignores the rest; trust is a key lookup, not a registry.
///
/// Attachment is doubly gated: the `RecordingAdminCap` authorizes the mutation
/// (the rights holder consents to writing the recording), and the ingester
/// witness authorizes the namespace. Detaching and reads require only the
/// recording, since removing or inspecting a master cannot forge trust.
module recording_master::master;

use miso::recording::{Recording, RecordingAdminCap};
use std::type_name::{Self, TypeName};
use sui::dynamic_field as df;

// === Keys ===

/// Dynamic-field key namespacing a master by `(ingester, content_digest)`.
///
/// - `ingester`: the defining `TypeName` of the ingester witness — unforgeable
///   (set from the witness in `add`, never from caller input).
/// - `content_digest`: discriminates multiple masters from the same ingester
///   (e.g. the PCM digest) and is the stable, storage-independent handle — it
///   survives re-keying / re-encoding, so a distributor can bind to a master by
///   `(ingester, content_digest)` across key rotation.
public struct ExtensionKey has copy, drop, store {
    ingester: TypeName,
    content_digest: vector<u8>,
}

// === Mutation ===

/// Adds `master` under ingester `W`'s namespace, discriminated by
/// `content_digest`. Requires the witness `W` (proves ingester authority) and
/// the recording's `RecordingAdminCap` (proves the rights holder consents).
/// Aborts if a master is already present under this exact `(ingester, digest)`.
public fun add<RecordingShare, CompositionShare, W: drop, M: store>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    _witness: W,
    content_digest: vector<u8>,
    master: M,
) {
    df::add(
        self.uid_mut(cap),
        ExtensionKey { ingester: type_name::with_defining_ids<W>(), content_digest },
        master,
    );
}

/// Detaches and returns a master. Gated only by the `RecordingAdminCap` — the
/// recording owner may remove any attached master; no witness is needed because
/// detaching cannot forge trust (only *writing* a namespace requires the
/// witness). `M` must match the stored value's type. Useful for key rotation:
/// remove the old encrypted master, add a freshly re-keyed one under the same
/// digest.
public fun remove<RecordingShare, CompositionShare, M: store>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    ingester: TypeName,
    content_digest: vector<u8>,
): M {
    df::remove(self.uid_mut(cap), ExtensionKey { ingester, content_digest })
}

// === Reads ===

/// Borrows the master attached under `(ingester, content_digest)`.
public fun borrow<RecordingShare, CompositionShare, M: store>(
    self: &Recording<RecordingShare, CompositionShare>,
    ingester: TypeName,
    content_digest: vector<u8>,
): &M {
    df::borrow(self.uid(), ExtensionKey { ingester, content_digest })
}

/// Whether a master is attached under `(ingester, content_digest)`.
public fun exists_<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
    ingester: TypeName,
    content_digest: vector<u8>,
): bool {
    df::exists(self.uid(), ExtensionKey { ingester, content_digest })
}

// === Key helpers ===

/// Builds a `ExtensionKey` — e.g. for clients constructing the dynamic-field id.
public fun new_key(ingester: TypeName, content_digest: vector<u8>): ExtensionKey {
    ExtensionKey { ingester, content_digest }
}

/// The ingester namespace of a key.
public fun key_ingester(key: &ExtensionKey): TypeName { key.ingester }

/// The content digest of a key.
public fun key_content_digest(key: &ExtensionKey): vector<u8> { key.content_digest }
