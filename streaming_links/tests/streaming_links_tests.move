// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module streaming_links::streaming_links_tests;

use miso::disc;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use std::unit_test::destroy;
use streaming_links::platforms;
use streaming_links::release_links;
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

// === Release-level links ===

#[test]
fun release_links_set_read_and_urls() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    assert!(!release_links::has_links(&rel));
    assert!(release_links::release_links(&rel).is_none());

    let links = platforms::empty()
        .with_spotify(platforms::new_spotify(b"27ftYHLeunzcSzb33Wk1hf".to_string()))
        .with_apple_music(platforms::new_apple_music_album(b"us".to_string(), b"1440783617".to_string()))
        .with_tidal(platforms::new_tidal(b"77640617".to_string()));
    release_links::set_release_links(&mut rel, &cap, links);

    assert!(release_links::has_links(&rel));
    let got = release_links::release_links(&rel).destroy_some();

    let spotify = got.spotify().destroy_some();
    assert!(
        spotify.spotify_album_url() == b"https://open.spotify.com/album/27ftYHLeunzcSzb33Wk1hf".to_string(),
    );

    let apple = got.apple_music().destroy_some();
    assert!(apple.apple_music_url() == b"https://music.apple.com/us/album/1440783617".to_string());

    let tidal = got.tidal().destroy_some();
    assert!(tidal.tidal_album_url() == b"https://tidal.com/browse/album/77640617".to_string());

    // Platforms not provided stay absent.
    assert!(got.youtube_music().is_none());
    assert!(got.deezer().is_none());

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test]
fun set_release_links_replaces_whole_set() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    release_links::set_release_links(
        &mut rel,
        &cap,
        platforms::empty().with_spotify(platforms::new_spotify(b"aaa".to_string())),
    );
    // Replacing with a deezer-only set drops the spotify link.
    release_links::set_release_links(
        &mut rel,
        &cap,
        platforms::empty().with_deezer(platforms::new_deezer(b"302127".to_string())),
    );

    let got = release_links::release_links(&rel).destroy_some();
    assert!(got.spotify().is_none());
    assert!(got.deezer().is_some());

    destroy(rel);
    destroy(cap);
    ts.end();
}

// === Per-track links ===

#[test]
fun track_links_set_read_and_urls() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    let track = platforms::empty()
        .with_spotify(platforms::new_spotify(b"6rqhFgbbKwnb9MLmUQDhG6".to_string()))
        .with_apple_music(
            platforms::new_apple_music_track(
                b"us".to_string(),
                b"1440783617".to_string(),
                b"1440783619".to_string(),
            ),
        )
        .with_amazon_music(
            platforms::new_amazon_music_track(b"B076YSK8CS".to_string(), b"B076YT2CBT".to_string()),
        );
    release_links::set_track_links(&mut rel, &cap, 1, track);

    let got = release_links::track_links(&rel, 1).destroy_some();

    let spotify = got.spotify().destroy_some();
    assert!(
        spotify.spotify_track_url() == b"https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6".to_string(),
    );

    let apple = got.apple_music().destroy_some();
    assert!(
        apple.apple_music_url() == b"https://music.apple.com/us/album/1440783617?i=1440783619".to_string(),
    );

    let amazon = got.amazon_music().destroy_some();
    assert!(
        amazon.amazon_music_url() == b"https://music.amazon.com/albums/B076YSK8CS?trackAsin=B076YT2CBT".to_string(),
    );

    // Other tracks are untouched / empty.
    assert!(release_links::track_links(&rel, 0).destroy_some().is_empty());
    assert!(release_links::track_links(&rel, 2).destroy_some().is_empty());

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test]
fun track_links_initialize_without_release_links() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    // Setting a per-track link first (no album-level set yet) initializes the
    // record, leaving the album-level set empty.
    release_links::set_track_links(
        &mut rel,
        &cap,
        2,
        platforms::empty().with_deezer(platforms::new_deezer(b"3135556".to_string())),
    );

    assert!(release_links::release_links(&rel).destroy_some().is_empty());
    assert!(release_links::track_links(&rel, 2).destroy_some().deezer().is_some());

    destroy(rel);
    destroy(cap);
    ts.end();
}

// === Clearing ===

#[test]
fun clear_track_resets_to_empty() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    release_links::set_track_links(
        &mut rel,
        &cap,
        0,
        platforms::empty().with_spotify(platforms::new_spotify(b"abc".to_string())),
    );
    assert!(!release_links::track_links(&rel, 0).destroy_some().is_empty());

    release_links::clear_track(&mut rel, &cap, 0);
    assert!(release_links::track_links(&rel, 0).destroy_some().is_empty());
    // The record still exists after clearing a single track.
    assert!(release_links::has_links(&rel));

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test]
fun clear_removes_whole_record() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());

    release_links::set_release_links(
        &mut rel,
        &cap,
        platforms::empty().with_spotify(platforms::new_spotify(b"abc".to_string())),
    );
    assert!(release_links::has_links(&rel));

    release_links::clear(&mut rel, &cap);
    assert!(!release_links::has_links(&rel));
    assert!(release_links::release_links(&rel).is_none());

    // Clearing again is a no-op.
    release_links::clear(&mut rel, &cap);

    destroy(rel);
    destroy(cap);
    ts.end();
}

#[test, expected_failure(abort_code = 2, location = streaming_links::release_links)] // ETrackIndexOutOfBounds
fun set_track_links_rejects_out_of_bounds_index() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx()); // 3 tracks → index 3 is invalid
    release_links::set_track_links(&mut rel, &cap, 3, platforms::empty());
    abort
}

// === URL builder formats (the remaining platforms / shapes) ===

#[test]
fun url_builders_cover_all_platforms() {
    // YouTube Music: album = playlist, track = video.
    let yt = platforms::new_youtube_music(b"OLAK5uy_k123".to_string());
    assert!(
        yt.youtube_music_album_url() == b"https://music.youtube.com/playlist?list=OLAK5uy_k123".to_string(),
    );
    let yt_track = platforms::new_youtube_music(b"dQw4w9WgXcQ".to_string());
    assert!(
        yt_track.youtube_music_track_url() == b"https://music.youtube.com/watch?v=dQw4w9WgXcQ".to_string(),
    );

    // Amazon Music album (no track selector).
    let amazon = platforms::new_amazon_music_album(b"B0064UPU4G".to_string());
    assert!(amazon.amazon_music_url() == b"https://music.amazon.com/albums/B0064UPU4G".to_string());

    // Deezer.
    let deezer = platforms::new_deezer(b"302127".to_string());
    assert!(deezer.deezer_album_url() == b"https://www.deezer.com/album/302127".to_string());
    assert!(deezer.deezer_track_url() == b"https://www.deezer.com/track/302127".to_string());

    // Tidal track.
    let tidal = platforms::new_tidal(b"77640617".to_string());
    assert!(tidal.tidal_track_url() == b"https://tidal.com/browse/track/77640617".to_string());

    // SoundCloud: album/playlist uses /sets/, track does not.
    let sc = platforms::new_soundcloud(b"artist".to_string(), b"my-ep".to_string());
    assert!(sc.soundcloud_set_url() == b"https://soundcloud.com/artist/sets/my-ep".to_string());
    let sc_track = platforms::new_soundcloud(b"artist".to_string(), b"my-song".to_string());
    assert!(sc_track.soundcloud_track_url() == b"https://soundcloud.com/artist/my-song".to_string());

    // Bandcamp: artist subdomain + slug.
    let bc = platforms::new_bandcamp(b"artist".to_string(), b"the-album".to_string());
    assert!(bc.bandcamp_album_url() == b"https://artist.bandcamp.com/album/the-album".to_string());
    let bc_track = platforms::new_bandcamp(b"artist".to_string(), b"the-song".to_string());
    assert!(bc_track.bandcamp_track_url() == b"https://artist.bandcamp.com/track/the-song".to_string());
}

#[test, expected_failure(abort_code = 0, location = streaming_links::platforms)] // EEmptyIdentifier
fun empty_identifier_is_rejected() {
    let _ = platforms::new_spotify(b"".to_string());
    abort
}
