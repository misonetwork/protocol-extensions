// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Spotify payload for the DSP-link extension. Spotify addresses both albums and
/// tracks by a single 22-char base62 id (`open.spotify.com/album/{id}` or
/// `/track/{id}`); album-vs-track is chosen by where the link is stored (the
/// release-level slot vs a per-track slot), so one `id` field serves both.
module release_dsp_link_spotify::release_dsp_link_spotify;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

// === Errors ===

/// The id was empty.
const EEmptyId: u64 = 0;

// === Type ===

/// Spotify's native id — a 22-char base62 album or track id.
public struct SpotifyData has copy, drop, store {
    id: String,
}

// === Constructor / accessor ===

/// Builds a Spotify link from its id. Aborts if `id` is empty.
public fun new(id: String): DspLink<SpotifyData> {
    assert!(!id.is_empty(), EEmptyId);
    dsp_link::new(SpotifyData { id })
}

/// The stored Spotify id.
public fun id(self: &SpotifyData): String {
    self.id
}
