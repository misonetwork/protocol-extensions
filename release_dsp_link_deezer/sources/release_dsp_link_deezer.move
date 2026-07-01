// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Deezer payload for the DSP-link extension. Deezer addresses albums and tracks
/// by a numeric id (`www.deezer.com/album/{id}` / `www.deezer.com/track/{id}`;
/// a `/{locale}/` segment may appear but is optional). Album-vs-track is chosen
/// by where the link is stored, so one `id` field serves both.
module release_dsp_link_deezer::release_dsp_link_deezer;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// The id was empty.
const EEmptyId: u64 = 0;

/// Deezer's native id — a numeric album or track id.
public struct DeezerData has copy, drop, store {
    id: String,
}

/// Builds a Deezer link from its id. Aborts if `id` is empty.
public fun new(id: String): DspLink<DeezerData> {
    assert!(!id.is_empty(), EEmptyId);
    dsp_link::new(DeezerData { id })
}

/// The stored Deezer id.
public fun id(self: &DeezerData): String {
    self.id
}
