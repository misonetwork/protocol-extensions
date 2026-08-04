// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// `PerTrack<Data>` — one `Data` value per track of a release, held in
/// tracklist order.
///
/// A release's tracks are a flat, ordered `vector<Track>`, frozen at release
/// creation. `PerTrack` is the parallel array to that list: index `i` holds the
/// payload for the `i`-th track. It is the shared shape behind per-track release
/// metadata such as cover art (`PerTrack<Option<CoverArt>>`) or genre — and the
/// natural home for display grouping (disc/side boundaries), which core
/// deliberately does not store.
///
/// Construction reads the `Release` and sizes/validates the array against
/// `total_tracks()`, so a `PerTrack` is parallel to the tracklist *by
/// construction* — an extension cannot attach a misaligned array. Because a
/// release's tracklist is frozen at creation, that alignment holds for the
/// release's whole life.
module per_track::per_track;

use miso::release::Release;

// === Structs ===

/// One `Data` per track, indexed by the release's tracklist position.
/// `Data` is the per-track payload — e.g. `CoverArt` when every track carries
/// one, or `Option<CoverArt>` for override-style metadata layered over an
/// album-level default.
public struct PerTrack<Data: store + drop>(vector<Data>) has store, drop;

// === Errors ===

/// Track index is past the end of the data.
const EIndexOutOfBounds: u64 = 0;
/// `entries` length does not match the release's track count.
const ELengthMismatch: u64 = 1;

// === Constructors ===

/// Builds a `PerTrack` from one value per track, in tracklist order. Aborts
/// unless `entries.length()` equals the release's track count.
public fun new<Data: store + drop>(release: &Release, entries: vector<Data>): PerTrack<Data> {
    assert!(entries.length() == release.total_tracks(), ELengthMismatch);
    PerTrack(entries)
}

/// Builds a `PerTrack` sized to the release's track count, with every track
/// initialized to `value`. The natural starting point for override-style
/// metadata: fill with `option::none()`, then set individual tracks via
/// `borrow_mut`.
public fun filled<Data: store + drop + copy>(release: &Release, value: Data): PerTrack<Data> {
    let n = release.total_tracks();
    let mut entries = vector[];
    let mut i = 0;
    while (i < n) {
        entries.push_back(value);
        i = i + 1;
    };
    PerTrack(entries)
}

// === Mutation ===

/// Borrows the payload for track `i` mutably. Aborts if `i` is out of range.
public fun borrow_mut<Data: store + drop>(self: &mut PerTrack<Data>, i: u64): &mut Data {
    assert!(i < self.0.length(), EIndexOutOfBounds);
    &mut self.0[i]
}

// === Reads ===

/// The number of tracks this covers.
public fun length<Data: store + drop>(self: &PerTrack<Data>): u64 {
    self.0.length()
}

/// Borrows the payload for track `i`. Aborts if `i` is out of range.
public fun borrow<Data: store + drop>(self: &PerTrack<Data>, i: u64): &Data {
    assert!(i < self.0.length(), EIndexOutOfBounds);
    &self.0[i]
}

// === Test Only ===

/// Builds a `PerTrack` directly from `entries`, bypassing the release check, so
/// the index/bounds logic can be unit-tested without constructing a `Release`.
/// The release-bound invariant is exercised by the consuming extensions' tests.
#[test_only]
public fun from_entries_for_testing<Data: store + drop>(entries: vector<Data>): PerTrack<Data> {
    PerTrack(entries)
}
