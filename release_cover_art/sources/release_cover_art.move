// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Release cover art: an album-level cover plus optional per-track cover
/// overrides. Stored as a dynamic field on the release's UID, set/cleared via
/// the release's cap-gated `uid_mut`.
///
/// Cover art is presentation, not objective recording data, so it lives on the
/// release (the consumer object) rather than the recording. A track's effective
/// cover resolves as: its per-track override if set, else the album cover. The
/// overrides are a `PerTrack<Option<CoverArt>>` — one slot per track, aligned to
/// the release's tracklist by construction (sized from `total_tracks()`).
module release_cover_art::release_cover_art;

use cover_art::cover_art::CoverArt;
use miso::release::{Release, ReleaseAdminCap};
use per_track::per_track::{Self, PerTrack};
use sui::dynamic_field as df;

// === Errors ===

/// No cover art record is attached to this release.
const ENoCoverArt: u64 = 1;
/// Track index is out of bounds for this release's track count.
const ETrackIndexOutOfBounds: u64 = 2;

// === Dynamic field key + value ===

/// Dynamic-field key — one cover art record per release.
public struct CoverArtKey() has copy, drop, store;

/// The release's cover art: an album-level cover and per-track overrides. A
/// track with no override inherits the album cover.
public struct ReleaseCoverArt has store {
    cover: Option<CoverArt>,
    track_covers: PerTrack<Option<CoverArt>>,
}

// === Write API ===

/// Sets (or replaces) the album-level cover.
public fun set_cover(self: &mut Release, cap: &ReleaseAdminCap, art: CoverArt) {
    borrow_mut_or_init(self, cap).cover.swap_or_fill(art);
}

/// Removes the album-level cover, if any. Per-track overrides are untouched.
public fun unset_cover(self: &mut Release, cap: &ReleaseAdminCap) {
    if (has_cover_art(self)) {
        borrow_mut(self.uid_mut(cap)).cover = option::none();
    }
}

/// Sets (or replaces) the cover override for a specific track (by tracklist
/// index). Aborts if the index is out of range for the release.
public fun set_track_cover(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    track_index: u64,
    art: CoverArt,
) {
    assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
    borrow_mut_or_init(self, cap).track_covers.borrow_mut(track_index).swap_or_fill(art);
}

/// Removes the cover override for a specific track, if any — the track then
/// falls back to the album cover.
public fun unset_track_cover(self: &mut Release, cap: &ReleaseAdminCap, track_index: u64) {
    if (has_cover_art(self)) {
        assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
        *borrow_mut(self.uid_mut(cap)).track_covers.borrow_mut(track_index) = option::none();
    }
}

// === Public View Functions ===

/// Returns whether a cover art record is attached to this release.
public fun has_cover_art(self: &Release): bool {
    df::exists(self.uid(), CoverArtKey())
}

/// Returns the album-level cover (none if unset). Aborts if no cover art record
/// is attached at all.
public fun cover(self: &Release): &Option<CoverArt> {
    &borrow(self.uid()).cover
}

/// Returns a track's effective cover: its per-track override if set, otherwise
/// the album cover (which may itself be none). Aborts if no cover art record is
/// attached, or if the track index is out of range.
public fun track_cover(self: &Release, track_index: u64): Option<CoverArt> {
    assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
    let record = borrow(self.uid());
    let override = record.track_covers.borrow(track_index);
    if (override.is_some()) *override else record.cover
}

// === Private Functions ===

fun borrow(uid: &UID): &ReleaseCoverArt {
    assert!(df::exists(uid, CoverArtKey()), ENoCoverArt);
    df::borrow(uid, CoverArtKey())
}

fun borrow_mut(uid: &mut UID): &mut ReleaseCoverArt {
    assert!(df::exists(uid, CoverArtKey()), ENoCoverArt);
    df::borrow_mut(uid, CoverArtKey())
}

fun borrow_mut_or_init(self: &mut Release, cap: &ReleaseAdminCap): &mut ReleaseCoverArt {
    if (!df::exists(self.uid(), CoverArtKey())) {
        // Size the per-track overrides to the tracklist up front (all empty);
        // the release's track count is fixed at creation, so this stays valid.
        let track_covers = per_track::filled(self, option::none<CoverArt>());
        df::add(
            self.uid_mut(cap),
            CoverArtKey(),
            ReleaseCoverArt { cover: option::none(), track_covers },
        );
    };
    borrow_mut(self.uid_mut(cap))
}
