// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link::release_dsp_link_tests;

use dsp_link::dsp_link as dl;
use release_dsp_link::release_dsp_link as links;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use std::unit_test::destroy;
use sui::test_scenario;

const A: address = @0xA1;

// A stand-in DSP payload. The attachment is generic, so any copy+drop+store
// type exercises it — keeping this package decoupled from any specific DSP.
public struct TestDsp has copy, drop, store {
    id: u64,
}

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
fun release_and_track_links_set_read_clear() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    assert!(!links::has_release_link<TestDsp>(&rel));
    assert!(links::release_link<TestDsp>(&rel).is_none());

    // Album-level link.
    links::set_release_link(&mut rel, &cap, dl::new(TestDsp { id: 1 }));
    assert!(links::has_release_link<TestDsp>(&rel));
    assert!(links::release_link<TestDsp>(&rel).destroy_some().data().id == 1);

    // Setting again replaces.
    links::set_release_link(&mut rel, &cap, dl::new(TestDsp { id: 2 }));
    assert!(links::release_link<TestDsp>(&rel).destroy_some().data().id == 2);

    // Per-track link on track 1; other tracks inherit (none).
    links::set_track_link(&mut rel, &cap, 1, dl::new(TestDsp { id: 11 }));
    assert!(links::track_link<TestDsp>(&rel, 1).destroy_some().data().id == 11);
    assert!(links::track_link<TestDsp>(&rel, 0).is_none());
    assert!(links::track_link<TestDsp>(&rel, 2).is_none());

    // Clearing track 1 resets it to none.
    links::clear_track_link<TestDsp>(&mut rel, &cap, 1);
    assert!(links::track_link<TestDsp>(&rel, 1).is_none());

    // Clearing the album-level link.
    links::clear_release_link<TestDsp>(&mut rel, &cap);
    assert!(!links::has_release_link<TestDsp>(&rel));

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test]
fun track_link_none_before_any_array() {
    let mut ts = test_scenario::begin(A);
    let (rel, cap) = mk_release(ts.ctx());

    // No per-track array exists yet → every index reads none (not an abort).
    assert!(links::track_link<TestDsp>(&rel, 0).is_none());
    assert!(links::track_link<TestDsp>(&rel, 2).is_none());

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link::release_dsp_link)] // ETrackIndexOutOfBounds
fun set_track_link_rejects_out_of_bounds() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx()); // 3 tracks → index 3 is invalid
    links::set_track_link(&mut rel, &cap, 3, dl::new(TestDsp { id: 0 }));
    abort
}
