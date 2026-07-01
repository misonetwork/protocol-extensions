// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Amazon Music payload for the DSP-link extension. An album is
/// `music.amazon.com/albums/{album_id}`; a track within it adds the
/// `?trackAsin={track_id}` selector. Ids are ASINs (e.g. `B0064UPU4G`). The
/// optional `track_id` distinguishes the two forms — clients emit the track URL
/// when it is set, the album URL otherwise.
module release_dsp_link_amazon_music::release_dsp_link_amazon_music;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// A required identifier was empty.
const EEmptyIdentifier: u64 = 0;

/// Amazon Music's native identifier — the album ASIN and an optional track ASIN
/// selecting a track within that album.
public struct AmazonMusicData has copy, drop, store {
    album_id: String,
    track_id: Option<String>,
}

/// Builds an Amazon Music album link (no track selector). Aborts if `album_id`
/// is empty.
public fun new_album(album_id: String): DspLink<AmazonMusicData> {
    assert!(!album_id.is_empty(), EEmptyIdentifier);
    dsp_link::new(AmazonMusicData { album_id, track_id: option::none() })
}

/// Builds an Amazon Music track link — addresses `track_id` within its
/// `album_id`. Aborts if either ASIN is empty.
public fun new_track(album_id: String, track_id: String): DspLink<AmazonMusicData> {
    assert!(!album_id.is_empty() && !track_id.is_empty(), EEmptyIdentifier);
    dsp_link::new(AmazonMusicData { album_id, track_id: option::some(track_id) })
}

/// The album ASIN.
public fun album_id(self: &AmazonMusicData): String {
    self.album_id
}

/// The selected track within the album, or `none` for an album-level link.
public fun track_id(self: &AmazonMusicData): Option<String> {
    self.track_id
}
