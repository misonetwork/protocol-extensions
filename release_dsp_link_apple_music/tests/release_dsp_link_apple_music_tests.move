// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_apple_music::release_dsp_link_apple_music_tests;

use release_dsp_link_apple_music::release_dsp_link_apple_music as apple_music;

#[test]
fun album_link_has_no_track_id() {
    let link = apple_music::new_album(b"gb".to_string(), b"1798266851".to_string());
    let data = link.data();
    assert!(data.storefront() == b"gb".to_string());
    assert!(data.album_id() == b"1798266851".to_string());
    assert!(data.track_id().is_none());
}

#[test]
fun track_link_carries_track_id() {
    let link = apple_music::new_track(
        b"us".to_string(),
        b"1440783617".to_string(),
        b"1440783619".to_string(),
    );
    assert!(link.data().track_id() == option::some(b"1440783619".to_string()));
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_apple_music::release_dsp_link_apple_music)] // EEmptyIdentifier
fun rejects_empty_album_id() {
    let _ = apple_music::new_album(b"us".to_string(), b"".to_string());
    abort
}
