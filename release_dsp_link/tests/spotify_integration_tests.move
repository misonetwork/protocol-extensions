// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Integration test: a real DSP payload (`SpotifyData`) driven end-to-end
/// through the generic attachment. `release_dsp_link_spotify` is a test-only
/// dependency (`modes = ["test"]`), so it never enters the production graph.
#[test_only]
module release_dsp_link::spotify_integration_tests;

use release_dsp_link::release_dsp_link as links;
use release_dsp_link_spotify::release_dsp_link_spotify as spotify;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use std::unit_test::destroy;
use sui::test_scenario;

const A: address = @0xA1;

// A 3-track release: flat tracklist indices 0, 1, 2.
fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    let rel_id = test_helpers::fake_id(ctx);
    let r0 = test_helpers::fake_id(ctx);
    let r1 = test_helpers::fake_id(ctx);
    let r2 = test_helpers::fake_id(ctx);
    let tracks = vector[
        track::new_for_testing(r0, rel_id, 4000),
        track::new_for_testing(r1, rel_id, 3000),
        track::new_for_testing(r2, rel_id, 3000),
    ];
    release::new_for_testing(b"Album".to_string(), tracks, ctx)
}

#[test]
fun real_spotify_payload_end_to_end() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    // Album-level, using the real SpotifyData payload.
    links::set_release_link(&mut rel, &cap, spotify::new(b"3xTbtTM3BSRIGxzWSMaEpc".to_string()));
    assert!(
        links::release_link<spotify::SpotifyData>(&rel).destroy_some().data().id() == b"3xTbtTM3BSRIGxzWSMaEpc".to_string(),
    );

    // Per-track on track 1; other tracks inherit the album link.
    links::set_track_link(&mut rel, &cap, 1, spotify::new(b"6rqhFgbbKwnb9MLmUQDhG6".to_string()));
    assert!(
        links::track_link<spotify::SpotifyData>(&rel, 1).destroy_some().data().id() == b"6rqhFgbbKwnb9MLmUQDhG6".to_string(),
    );
    assert!(links::track_link<spotify::SpotifyData>(&rel, 0).is_none());

    destroy(rel);
    destroy(cap);
    ts.end();
}
