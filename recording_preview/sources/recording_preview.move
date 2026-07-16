// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Recording audio preview: a short, public teaser clip for a recording,
/// stored as a dynamic field on the recording's UID, set/cleared via the
/// recording's cap-gated `uid_mut`.
///
/// V1 is deliberately minimal: the value is a bare `ori::WalrusData` blob
/// reference — no ingestion or attestation ties the preview to the
/// recording's master. What the blob contains (codec, duration, clip offset)
/// is client-side convention, not protocol state. An attested preview
/// standard can ship later as its own extension without touching this one.
module recording_preview::recording_preview;

use miso::recording::{Recording, RecordingAdminCap};
use ori::walrus_data::WalrusData;
use sui::dynamic_field as df;

// === Errors ===

/// No preview is attached to this recording.
const ENoPreview: u64 = 1;

// === Dynamic field key ===

/// Dynamic-field key — one preview per recording.
public struct ExtensionKey() has copy, drop, store;

// === Write API ===

/// Sets (or replaces) the recording's preview. The reference must be a
/// standalone Walrus blob.
public fun set_preview<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    preview: WalrusData,
) {
    preview.assert_is_blob();
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        *df::borrow_mut(uid, ExtensionKey()) = preview;
    } else {
        df::add(uid, ExtensionKey(), preview);
    }
}

/// Removes the preview, if any.
public fun unset_preview<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: WalrusData = df::remove(uid, ExtensionKey());
    }
}

// === Public View Functions ===

/// Returns whether a preview is attached to this recording.
public fun has_preview<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// Borrows the preview's Walrus reference. Aborts if none is attached.
public fun preview<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &WalrusData {
    assert!(has_preview(self), ENoPreview);
    df::borrow(self.uid(), ExtensionKey())
}
