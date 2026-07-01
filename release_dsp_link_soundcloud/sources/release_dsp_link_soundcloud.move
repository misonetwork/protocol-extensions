// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// SoundCloud payload for the DSP-link extension. SoundCloud is slug-addressed,
/// not numeric: an album/playlist is `soundcloud.com/{user}/sets/{slug}` and a
/// track is `soundcloud.com/{user}/{slug}`. Album-vs-track is chosen by where
/// the link is stored, so one `(user, slug)` pair serves both.
module release_dsp_link_soundcloud::release_dsp_link_soundcloud;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// A required identifier was empty.
const EEmptyIdentifier: u64 = 0;

/// SoundCloud's native identifier — the `user` handle and the `slug` of the set
/// or track.
public struct SoundCloudData has copy, drop, store {
    user: String,
    slug: String,
}

/// Builds a SoundCloud link. Aborts if `user` or `slug` is empty.
public fun new(user: String, slug: String): DspLink<SoundCloudData> {
    assert!(!user.is_empty() && !slug.is_empty(), EEmptyIdentifier);
    dsp_link::new(SoundCloudData { user, slug })
}

/// The user handle.
public fun user(self: &SoundCloudData): String {
    self.user
}

/// The set or track slug.
public fun slug(self: &SoundCloudData): String {
    self.slug
}
