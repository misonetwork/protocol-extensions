// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Apple Music payload for the DSP-link extension. An album is
/// `music.apple.com/{storefront}/album/{album_id}`; a track within it adds the
/// `?i={track_id}` selector. `storefront` is the two-letter region (e.g. `us`),
/// and because a track link still needs the album id, the album id is always
/// present. The optional `track_id` distinguishes the two forms — clients emit
/// the track URL when it is set, the album URL otherwise.
///
/// The canonical web URL carries a cosmetic name slug
/// (`/album/{slug}/{album_id}`); only the trailing numeric `album_id` is stored,
/// and Apple resolves the slug-less form.
module release_dsp_link_apple_music::release_dsp_link_apple_music;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// A required identifier was empty.
const EEmptyIdentifier: u64 = 0;

/// Apple Music's native identifier — region `storefront`, the `album_id`, and an
/// optional `track_id` selecting a track within that album.
public struct AppleMusicData has copy, drop, store {
    storefront: String,
    album_id: String,
    track_id: Option<String>,
}

/// Builds an Apple Music album link (no track selector). Aborts if `storefront`
/// or `album_id` is empty.
public fun new_album(storefront: String, album_id: String): DspLink<AppleMusicData> {
    assert!(!storefront.is_empty() && !album_id.is_empty(), EEmptyIdentifier);
    dsp_link::new(AppleMusicData { storefront, album_id, track_id: option::none() })
}

/// Builds an Apple Music track link — addresses `track_id` within its
/// `album_id`. Aborts if any identifier is empty.
public fun new_track(
    storefront: String,
    album_id: String,
    track_id: String,
): DspLink<AppleMusicData> {
    assert!(
        !storefront.is_empty() && !album_id.is_empty() && !track_id.is_empty(),
        EEmptyIdentifier,
    );
    dsp_link::new(AppleMusicData { storefront, album_id, track_id: option::some(track_id) })
}

/// The region storefront (e.g. `us`).
public fun storefront(self: &AppleMusicData): String {
    self.storefront
}

/// The album id.
public fun album_id(self: &AppleMusicData): String {
    self.album_id
}

/// The selected track within the album, or `none` for an album-level link.
public fun track_id(self: &AppleMusicData): Option<String> {
    self.track_id
}
