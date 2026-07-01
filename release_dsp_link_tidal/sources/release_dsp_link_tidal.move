// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Tidal payload for the DSP-link extension. Tidal addresses albums and tracks
/// by a numeric id (`tidal.com/album/{id}` / `tidal.com/track/{id}`; the older
/// `tidal.com/browse/album/{id}` form also resolves). Album-vs-track is chosen
/// by where the link is stored, so one `id` field serves both.
module release_dsp_link_tidal::release_dsp_link_tidal;

use dsp_link::dsp_link::{Self, DspLink};
use std::string::String;

/// The id was empty.
const EEmptyId: u64 = 0;

/// Tidal's native id — a numeric album or track id.
public struct TidalData has copy, drop, store {
    id: String,
}

/// Builds a Tidal link from its id. Aborts if `id` is empty.
public fun new(id: String): DspLink<TidalData> {
    assert!(!id.is_empty(), EEmptyId);
    dsp_link::new(TidalData { id })
}

/// The stored Tidal id.
public fun id(self: &TidalData): String {
    self.id
}
