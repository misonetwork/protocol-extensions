// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// YouTube Music payload for the DSP-link extension. An album is a playlist
/// (`music.youtube.com/playlist?list={id}`) and a track is a video
/// (`music.youtube.com/watch?v={id}`). The `id` holds the playlist id at the
/// release level and the video id per track; album-vs-track is chosen by where
/// the link is stored, so one `id` field serves both.
module release_dsp_link_youtube_music::release_dsp_link_youtube_music;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// The id was empty.
const EEmptyId: u64 = 0;

/// YouTube Music's native id — a playlist id (album) or video id (track).
public struct YouTubeMusicData has copy, drop, store {
    id: String,
}

/// Builds a YouTube Music link from its id. Aborts if `id` is empty.
public fun new(id: String): DspLink<YouTubeMusicData> {
    assert!(!id.is_empty(), EEmptyId);
    dsp_link::new(YouTubeMusicData { id })
}

/// The stored YouTube Music id.
public fun id(self: &YouTubeMusicData): String {
    self.id
}
