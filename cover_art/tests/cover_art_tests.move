// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module cover_art::cover_art_tests;

use cover_art::cover_art as cover;
use cover_art::release_cover_art;
use miso::disc;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use std::unit_test::destroy;
use sui::test_scenario;

const A: address = @0xA1;

// A 3-track release across 2 discs. Disc-major tracklist order: (d0t0, d0t1,
// d1t0) → indices 0, 1, 2.
fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    let rel_id = test_helpers::fake_id(ctx);
    let r0 = test_helpers::fake_id(ctx);
    let r1 = test_helpers::fake_id(ctx);
    let r2 = test_helpers::fake_id(ctx);
    let d0 = disc::new(
        vector[
            track::new_for_testing(r0, rel_id, 4000),
            track::new_for_testing(r1, rel_id, 3000),
        ],
        option::none(),
    );
    let d1 = disc::new(vector[track::new_for_testing(r2, rel_id, 3000)], option::none());
    release::new_for_testing(b"Album".to_string(), vector[d0, d1], ctx)
}

#[test]
fun album_cover_set_read_unset() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    assert!(!release_cover_art::has_cover_art(&rel));
    release_cover_art::set_cover(&mut rel, &cap, cover::new_for_testing());
    assert!(release_cover_art::has_cover_art(&rel));
    assert!(release_cover_art::cover(&rel).is_some());

    release_cover_art::unset_cover(&mut rel, &cap);
    assert!(release_cover_art::cover(&rel).is_none());

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test]
fun track_cover_override_resolves_over_album() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    release_cover_art::set_cover(&mut rel, &cap, cover::new_for_testing());

    // No override yet: every track resolves to the album cover.
    assert!(release_cover_art::track_cover(&rel, 0).is_some());
    assert!(release_cover_art::track_cover(&rel, 2).is_some());

    // Set an override on track 1.
    release_cover_art::set_track_cover(&mut rel, &cap, 1, cover::new_for_testing());
    assert!(release_cover_art::track_cover(&rel, 1).is_some());

    // Clear it; track 1 falls back to the album cover.
    release_cover_art::unset_track_cover(&mut rel, &cap, 1);
    assert!(release_cover_art::track_cover(&rel, 1).is_some());

    // With the album cover unset and no override, a track resolves to none.
    release_cover_art::unset_cover(&mut rel, &cap);
    assert!(release_cover_art::track_cover(&rel, 0).is_none());

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test, expected_failure(abort_code = 2, location = cover_art::release_cover_art)] // ETrackIndexOutOfBounds
fun set_track_cover_rejects_out_of_bounds_index() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx()); // 3 tracks → index 3 is invalid
    release_cover_art::set_track_cover(&mut rel, &cap, 3, cover::new_for_testing());
    abort
}
