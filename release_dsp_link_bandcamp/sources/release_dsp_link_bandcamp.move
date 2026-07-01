// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Bandcamp payload for the DSP-link extension. Bandcamp addresses by artist
/// subdomain + slug: an album is `{subdomain}.bandcamp.com/album/{slug}` and a
/// track is `{subdomain}.bandcamp.com/track/{slug}`. Album-vs-track is chosen by
/// where the link is stored, so one `(subdomain, slug)` pair serves both.
module release_dsp_link_bandcamp::release_dsp_link_bandcamp;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// A required identifier was empty.
const EEmptyIdentifier: u64 = 0;

/// Bandcamp's native identifier — the artist `subdomain` and the `slug` of the
/// album or track.
public struct BandcampData has copy, drop, store {
    subdomain: String,
    slug: String,
}

/// Builds a Bandcamp link. Aborts if `subdomain` or `slug` is empty.
public fun new(subdomain: String, slug: String): DspLink<BandcampData> {
    assert!(!subdomain.is_empty() && !slug.is_empty(), EEmptyIdentifier);
    dsp_link::new(BandcampData { subdomain, slug })
}

/// The artist subdomain.
public fun subdomain(self: &BandcampData): String {
    self.subdomain
}

/// The album or track slug.
public fun slug(self: &BandcampData): String {
    self.slug
}
