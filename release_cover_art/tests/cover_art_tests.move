// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_cover_art::cover_art_tests;

use cover_art::cover_art as cover;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use release_cover_art::release_cover_art;
use std::unit_test::{assert_eq, destroy};
use sui::event;
use sui::test_scenario;

const A: address = @0xA1;

// Mirrored from miso::release::EUnauthorized (private there).
const EUnauthorized: u64 = 0;
// Mirrored from release_cover_art::release_cover_art (both private there).
const ENoCoverArt: u64 = 1;
const ETrackIndexOutOfBounds: u64 = 2;

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

#[test, expected_failure(abort_code = ETrackIndexOutOfBounds, location = release_cover_art)]
fun set_track_cover_rejects_out_of_bounds_index() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx()); // 3 tracks → index 3 is invalid
    release_cover_art::set_track_cover(&mut rel, &cap, 3, cover::new_for_testing());
    abort
}

// === Event assertions ===

#[test]
fun set_cover_emits_release_and_art() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);

    release_cover_art::set_cover(&mut rel, &cap, cover::new_for_testing());

    let events = event::events_by_type<release_cover_art::CoverSetEvent>();
    assert_eq!(events.length(), 1);
    let (release_id, art) = release_cover_art::cover_set_event_fields(&events[0]);
    assert_eq!(release_id, rel_id);
    assert_eq!(art, cover::new_for_testing());

    destroy(rel);
    destroy(cap);
}

#[test]
fun unset_cover_emits_release_id() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);

    release_cover_art::set_cover(&mut rel, &cap, cover::new_for_testing());
    release_cover_art::unset_cover(&mut rel, &cap);

    let events = event::events_by_type<release_cover_art::CoverUnsetEvent>();
    assert_eq!(events.length(), 1);
    assert_eq!(release_cover_art::cover_unset_event_release_id(&events[0]), rel_id);

    destroy(rel);
    destroy(cap);
}

#[test]
fun set_track_cover_emits_release_index_and_art() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);

    // A per-track set lazily initializes the record (no album cover first).
    release_cover_art::set_track_cover(&mut rel, &cap, 1, cover::new_for_testing());

    let events = event::events_by_type<release_cover_art::TrackCoverSetEvent>();
    assert_eq!(events.length(), 1);
    let (release_id, track_index, art) = release_cover_art::track_cover_set_event_fields(&events[0]);
    assert_eq!(release_id, rel_id);
    assert_eq!(track_index, 1);
    assert_eq!(art, cover::new_for_testing());

    destroy(rel);
    destroy(cap);
}

#[test]
fun unset_track_cover_emits_release_and_index() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);

    release_cover_art::set_track_cover(&mut rel, &cap, 1, cover::new_for_testing());
    release_cover_art::unset_track_cover(&mut rel, &cap, 1);

    let events = event::events_by_type<release_cover_art::TrackCoverUnsetEvent>();
    assert_eq!(events.length(), 1);
    let (release_id, track_index) = release_cover_art::track_cover_unset_event_fields(&events[0]);
    assert_eq!(release_id, rel_id);
    assert_eq!(track_index, 1);

    destroy(rel);
    destroy(cap);
}

// === Wrong-cap authorization ===

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun set_cover_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, _cap) = mk_release(ctx);
    let (_other_rel, other_cap) = mk_release(ctx);

    release_cover_art::set_cover(&mut rel, &other_cap, cover::new_for_testing());
    abort
}

// Regression test for the cap-gate-order finding: with nothing attached, the
// old existence-check-first code never reached `uid_mut` and silently
// succeeded under a wrong cap.
#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun unset_cover_with_wrong_cap_aborts_when_unattached() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, _cap) = mk_release(ctx);
    let (_other_rel, other_cap) = mk_release(ctx);

    release_cover_art::unset_cover(&mut rel, &other_cap);
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun set_track_cover_with_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, _cap) = mk_release(ctx);
    let (_other_rel, other_cap) = mk_release(ctx);

    release_cover_art::set_track_cover(&mut rel, &other_cap, 0, cover::new_for_testing());
    abort
}

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun unset_track_cover_with_wrong_cap_aborts_when_unattached() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, _cap) = mk_release(ctx);
    let (_other_rel, other_cap) = mk_release(ctx);

    release_cover_art::unset_track_cover(&mut rel, &other_cap, 0);
    abort
}

// === Unattached aborts ===

#[test, expected_failure(abort_code = ENoCoverArt, location = release_cover_art)]
fun unset_cover_without_attachment_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);

    release_cover_art::unset_cover(&mut rel, &cap);
    abort
}

#[test, expected_failure(abort_code = ENoCoverArt, location = release_cover_art)]
fun unset_track_cover_without_attachment_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);

    release_cover_art::unset_track_cover(&mut rel, &cap, 0);
    abort
}

#[test, expected_failure(abort_code = ENoCoverArt, location = release_cover_art)]
fun cover_view_without_attachment_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _cap) = mk_release(ctx);

    let _ = release_cover_art::cover(&rel);
    abort
}

#[test, expected_failure(abort_code = ENoCoverArt, location = release_cover_art)]
fun track_cover_view_without_attachment_aborts() {
    let ctx = &mut tx_context::dummy();
    let (rel, _cap) = mk_release(ctx);

    let _ = release_cover_art::track_cover(&rel, 0);
    abort
}
