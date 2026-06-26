// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Streaming deep links for a Miso release: an album-level set of per-platform
/// links plus one optional set per track. Lets a frontend render "Stream on
/// Spotify / Apple Music / …" buttons for the release and for any individual
/// track.
///
/// Streaming presence is presentation, not objective recording data, so it
/// lives on the release (the consumer object), not the recording. The whole
/// thing is a single `ReleaseStreamingLinks` dynamic field on the release's
/// UID, gated by the `ReleaseAdminCap` via `uid_mut` — set and cleared like
/// cover art or genre.
///
/// The per-track sets are a `PerTrack<PlatformLinks>` — one slot per track,
/// aligned to the release's tracklist by construction (sized from
/// `total_tracks()`, disc-major order). A track with no links of its own simply
/// has an empty set; frontends fall back to the album-level link.
module streaming_links::release_links;

use miso::release::{Release, ReleaseAdminCap};
use per_track::per_track::{Self, PerTrack};
use streaming_links::platforms::{Self, PlatformLinks};
use sui::dynamic_field as df;
use sui::event::emit;

// === Errors ===

/// No streaming-links record is attached to this release.
const ENoStreamingLinks: u64 = 1;
/// Track index is out of bounds for this release's track count.
const ETrackIndexOutOfBounds: u64 = 2;

// === Dynamic field key + value ===

/// Dynamic-field key — one streaming-links record per release.
public struct StreamingLinksKey() has copy, drop, store;

/// A release's streaming links: an album-level set and per-track sets. A track
/// with an empty set inherits the album-level links at the frontend.
public struct ReleaseStreamingLinks has drop, store {
    release: PlatformLinks,
    tracks: PerTrack<PlatformLinks>,
}

// === Events ===

/// Emitted when the album-level link set is set or replaced.
public struct ReleaseLinksSetEvent has copy, drop {
    release_id: ID,
}

/// Emitted when a track's link set is set, replaced, or cleared.
public struct TrackLinksSetEvent has copy, drop {
    release_id: ID,
    track_index: u64,
}

/// Emitted when the whole streaming-links record is removed.
public struct LinksClearedEvent has copy, drop {
    release_id: ID,
}

// === Write API ===

/// Sets (or replaces) the album-level link set. Replaces the whole set — build
/// it with `platforms::empty().with_spotify(..).with_apple_music(..)` and pass
/// it here. Per-track sets are untouched.
public fun set_release_links(self: &mut Release, cap: &ReleaseAdminCap, links: PlatformLinks) {
    let release_id = self.id();
    borrow_mut_or_init(self, cap).release = links;
    emit(ReleaseLinksSetEvent { release_id });
}

/// Sets (or replaces) a single track's link set (by tracklist index). Replaces
/// the whole set for that track. Aborts if the index is out of range.
public fun set_track_links(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    track_index: u64,
    links: PlatformLinks,
) {
    assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
    let release_id = self.id();
    *borrow_mut_or_init(self, cap).tracks.borrow_mut(track_index) = links;
    emit(TrackLinksSetEvent { release_id, track_index });
}

/// Clears one track's links back to empty (the track falls back to the
/// album-level links). No-op if no record is attached. Aborts if the index is
/// out of range (when a record exists).
public fun clear_track(self: &mut Release, cap: &ReleaseAdminCap, track_index: u64) {
    if (df::exists(self.uid(), StreamingLinksKey())) {
        assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
        let release_id = self.id();
        *borrow_mut(self.uid_mut(cap)).tracks.borrow_mut(track_index) = platforms::empty();
        emit(TrackLinksSetEvent { release_id, track_index });
    }
}

/// Removes the entire streaming-links record (album-level and all per-track
/// sets). No-op if nothing is attached.
public fun clear(self: &mut Release, cap: &ReleaseAdminCap) {
    if (df::exists(self.uid(), StreamingLinksKey())) {
        let release_id = self.id();
        let _: ReleaseStreamingLinks = df::remove(self.uid_mut(cap), StreamingLinksKey());
        emit(LinksClearedEvent { release_id });
    }
}

// === Views ===

/// Whether a streaming-links record is attached to this release.
public fun has_links(self: &Release): bool {
    df::exists(self.uid(), StreamingLinksKey())
}

/// The album-level link set, if a record is attached.
public fun release_links(self: &Release): Option<PlatformLinks> {
    let uid = self.uid();
    if (df::exists(uid, StreamingLinksKey())) {
        option::some(borrow(uid).release)
    } else {
        option::none()
    }
}

/// A track's own link set (by tracklist index), if a record is attached. The
/// set may be empty, meaning the track inherits the album-level links. None if
/// no record is attached. Aborts if the index is out of range (when a record
/// exists).
public fun track_links(self: &Release, track_index: u64): Option<PlatformLinks> {
    let uid = self.uid();
    if (!df::exists(uid, StreamingLinksKey())) return option::none();
    assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
    option::some(*borrow(uid).tracks.borrow(track_index))
}

// === Private ===

fun borrow(uid: &UID): &ReleaseStreamingLinks {
    assert!(df::exists(uid, StreamingLinksKey()), ENoStreamingLinks);
    df::borrow(uid, StreamingLinksKey())
}

fun borrow_mut(uid: &mut UID): &mut ReleaseStreamingLinks {
    assert!(df::exists(uid, StreamingLinksKey()), ENoStreamingLinks);
    df::borrow_mut(uid, StreamingLinksKey())
}

fun borrow_mut_or_init(self: &mut Release, cap: &ReleaseAdminCap): &mut ReleaseStreamingLinks {
    if (!df::exists(self.uid(), StreamingLinksKey())) {
        // Size the per-track sets to the tracklist up front (all empty); the
        // release's track count is fixed at creation, so this stays valid.
        let tracks = per_track::filled(self, platforms::empty());
        df::add(
            self.uid_mut(cap),
            StreamingLinksKey(),
            ReleaseStreamingLinks { release: platforms::empty(), tracks },
        );
    };
    borrow_mut(self.uid_mut(cap))
}
