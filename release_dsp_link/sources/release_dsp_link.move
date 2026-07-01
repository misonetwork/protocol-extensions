// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Streaming deep links for a Miso release, one Digital Service Provider (DSP)
/// at a time. Attaches `DspLink<Data>` records to a `miso::release::Release`: an
/// album-level link per DSP, plus an optional per-track link per DSP.
///
/// Generic over the DSP payload `Data`, so this one module serves every DSP —
/// `set_release_link<SpotifyData>`, `set_release_link<AppleMusicData>`, … each
/// land in their own dynamic field (keyed by the `Data` type), so DSPs are
/// independent: adding one never rewrites another's record, and a new DSP needs
/// no change here.
///
/// Streaming presence is presentation, not protocol-verifiable state, so it
/// lives on the release (the consumer object), not the recording. All writes are
/// gated by the `ReleaseAdminCap` via `uid_mut`; views are permissionless.
///
/// Two levels per DSP: the album-level link is the single `DspLink<Data>` the
/// `dsp_link` primitive stores on the release UID; the per-track links are a
/// `PerTrack<Option<DspLink<Data>>>` (one slot per track, aligned to the
/// tracklist by construction). A track whose slot is `none` inherits the
/// album-level link at the frontend.
module release_dsp_link::release_dsp_link;

use dsp_link::dsp_link::{Self, DspLink};
use miso::release::{Release, ReleaseAdminCap};
use per_track::per_track::{Self, PerTrack};
use sui::dynamic_field as df;
use sui::event::emit;

// === Errors ===

/// Track index is out of bounds for this release's track count.
const ETrackIndexOutOfBounds: u64 = 0;

// === Keys ===

/// Dynamic-field key for a DSP's per-track links: a `PerTrack` of optional
/// links, one slot per track. `phantom Data` gives each DSP its own array.
public struct TrackLinksKey<phantom Data>() has copy, drop, store;

// === Events ===

/// Emitted when a DSP's album-level link is set or replaced.
public struct ReleaseLinkSetEvent<phantom Data> has copy, drop {
    release_id: ID,
}

/// Emitted when a DSP's album-level link is cleared.
public struct ReleaseLinkClearedEvent<phantom Data> has copy, drop {
    release_id: ID,
}

/// Emitted when a DSP's link for one track is set, replaced, or cleared.
public struct TrackLinkSetEvent<phantom Data> has copy, drop {
    release_id: ID,
    track_index: u64,
}

// === Album-level write API ===

/// Sets (or replaces) a DSP's album-level link. Per-track links are untouched.
public fun set_release_link<Data: copy + drop + store>(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    link: DspLink<Data>,
) {
    let release_id = self.id();
    dsp_link::set(self.uid_mut(cap), link);
    emit(ReleaseLinkSetEvent<Data> { release_id });
}

/// Clears a DSP's album-level link. No-op if unset.
public fun clear_release_link<Data: copy + drop + store>(
    self: &mut Release,
    cap: &ReleaseAdminCap,
) {
    if (dsp_link::exists_<Data>(self.uid())) {
        let release_id = self.id();
        dsp_link::clear<Data>(self.uid_mut(cap));
        emit(ReleaseLinkClearedEvent<Data> { release_id });
    }
}

// === Per-track write API ===

/// Sets (or replaces) a DSP's link for one track (by tracklist index). Aborts
/// if the index is out of range.
public fun set_track_link<Data: copy + drop + store>(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    track_index: u64,
    link: DspLink<Data>,
) {
    assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
    let release_id = self.id();
    *track_links_mut_or_init<Data>(self, cap).borrow_mut(track_index) = option::some(link);
    emit(TrackLinkSetEvent<Data> { release_id, track_index });
}

/// Clears a DSP's link for one track (the track falls back to the album-level
/// link). No-op if no per-track array exists for this DSP. Aborts if the index
/// is out of range (when an array exists).
public fun clear_track_link<Data: copy + drop + store>(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    track_index: u64,
) {
    if (df::exists(self.uid(), TrackLinksKey<Data>())) {
        assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
        let release_id = self.id();
        *borrow_track_links_mut<Data>(self.uid_mut(cap)).borrow_mut(track_index) = option::none();
        emit(TrackLinkSetEvent<Data> { release_id, track_index });
    }
}

/// Removes a DSP's entire per-track array. No-op if absent.
public fun clear_track_links<Data: copy + drop + store>(
    self: &mut Release,
    cap: &ReleaseAdminCap,
) {
    if (df::exists(self.uid(), TrackLinksKey<Data>())) {
        let _: PerTrack<Option<DspLink<Data>>> = df::remove(self.uid_mut(cap), TrackLinksKey<Data>());
    }
}

// === Views ===

/// Whether a DSP's album-level link is set.
public fun has_release_link<Data: copy + drop + store>(self: &Release): bool {
    dsp_link::exists_<Data>(self.uid())
}

/// A DSP's album-level link, if set.
public fun release_link<Data: copy + drop + store>(self: &Release): Option<DspLink<Data>> {
    dsp_link::get<Data>(self.uid())
}

/// A DSP's link for one track, if set. An unset slot — or no array at all —
/// yields `none`, meaning the track inherits the album-level link. Aborts if the
/// index is out of range (when an array exists).
public fun track_link<Data: copy + drop + store>(
    self: &Release,
    track_index: u64,
): Option<DspLink<Data>> {
    let uid = self.uid();
    if (!df::exists(uid, TrackLinksKey<Data>())) return option::none();
    assert!(track_index < self.total_tracks(), ETrackIndexOutOfBounds);
    *borrow_track_links<Data>(uid).borrow(track_index)
}

// === Private ===

fun borrow_track_links<Data: copy + drop + store>(
    uid: &UID,
): &PerTrack<Option<DspLink<Data>>> {
    df::borrow(uid, TrackLinksKey<Data>())
}

fun borrow_track_links_mut<Data: copy + drop + store>(
    uid: &mut UID,
): &mut PerTrack<Option<DspLink<Data>>> {
    df::borrow_mut(uid, TrackLinksKey<Data>())
}

fun track_links_mut_or_init<Data: copy + drop + store>(
    self: &mut Release,
    cap: &ReleaseAdminCap,
): &mut PerTrack<Option<DspLink<Data>>> {
    if (!df::exists(self.uid(), TrackLinksKey<Data>())) {
        // Size the array to the tracklist up front (all empty); the release's
        // track count is fixed at creation, so this stays valid.
        let tracks = per_track::filled(self, option::none<DspLink<Data>>());
        df::add(self.uid_mut(cap), TrackLinksKey<Data>(), tracks);
    };
    borrow_track_links_mut<Data>(self.uid_mut(cap))
}
