// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The on-chain pointer to a release's snapshot bundle: which Walrus quilt is
/// this release's bundle.
///
/// A snapshot bundle is curated bonus material a buyer gets access to — one
/// Walrus quilt, assembled after the fact. The quilt is self-describing: its
/// plaintext `manifest.json` patch carries all the metadata, its media patches
/// are chunk-encrypted under one AES envelope key, and that key travels
/// Seal-wrapped inside the quilt as its `key.seal` patch. This package
/// therefore stores none of that — no ciphertext, no metadata, no access
/// policy (unlocking by holding a Record is `miso_record_acl`'s concern, in
/// miso-record-extensions). The stored value is the quilt's `WalrusData` blob
/// reference, and nothing else.
///
/// The slot is write-once: `set_snapshot_bundle` aborts with
/// `EBundleAlreadySet` if a bundle is already set, and there is NO unset, NO
/// remove, and NO replace function. That absence is a product guarantee: the
/// bundle a buyer's Record points at can never be swapped out from under
/// them. More content later means a new Release.
module release_snapshot_bundle::release_snapshot_bundle;

use miso::release::{Release, ReleaseAdminCap};
use ori::walrus_data::WalrusData;
use sui::dynamic_field as df;
use sui::event::emit;

// === Errors ===

/// A snapshot bundle is already set — the slot is write-once.
const EBundleAlreadySet: u64 = 1;
/// No snapshot bundle is set on this release.
const ENoSnapshotBundle: u64 = 2;
/// The bundle reference must be a plaintext blob — the quilt's manifest is
/// readable by design; encryption is per-patch inside the quilt.
const EBundleMustBePlaintext: u64 = 3;

// === Structs ===

/// Dynamic-field key — one snapshot bundle per release, forever.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted once per release, when its snapshot bundle is set. Carries the
/// bundle reference itself: with no unset and no replace, this event is the
/// complete history of the slot, so an indexer writes its row straight from
/// the event without re-reading the object.
public struct SnapshotBundleSetEvent has copy, drop {
    release_id: ID,
    bundle: WalrusData,
}

// === Public Functions ===

/// Sets the release's snapshot bundle — once. Aborts with `EBundleAlreadySet`
/// if a bundle is already set; there is no way to unset or replace it.
///
/// The reference must be a plaintext standalone blob. A quilt patch is a
/// slice of some other quilt, not the bundle's own quilt blob. And the outer
/// quilt blob is plaintext by design: its `manifest.json` patch must be
/// readable, encryption is per-patch inside the quilt, and the Seal-wrapped
/// envelope key travels as the quilt's `key.seal` patch — so an encrypted
/// outer reference is structurally wrong. With no replace function either
/// mistake would be permanent, which is why both checks live on-chain rather
/// than in the client.
public fun set_snapshot_bundle(self: &mut Release, cap: &ReleaseAdminCap, bundle: WalrusData) {
    let release_id = self.id();
    // Cap gate first, on every path — authorization before argument validation.
    let uid = self.uid_mut(cap);
    bundle.assert_is_blob();
    assert!(!bundle.is_encrypted(), EBundleMustBePlaintext);
    assert!(!df::exists(uid, ExtensionKey()), EBundleAlreadySet);
    df::add(uid, ExtensionKey(), bundle);
    emit(SnapshotBundleSetEvent { release_id, bundle });
}

// === View Functions ===

/// Returns whether a snapshot bundle is set on this release.
public fun has_snapshot_bundle(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The release's snapshot bundle reference. Aborts with `ENoSnapshotBundle`
/// if none is set.
public fun snapshot_bundle(self: &Release): &WalrusData {
    assert!(has_snapshot_bundle(self), ENoSnapshotBundle);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun set_event_fields(e: &SnapshotBundleSetEvent): (ID, WalrusData) {
    (e.release_id, e.bundle)
}
