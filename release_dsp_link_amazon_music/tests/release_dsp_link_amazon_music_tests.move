// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_amazon_music::release_dsp_link_amazon_music_tests;

use release_dsp_link_amazon_music::release_dsp_link_amazon_music as amazon_music;

#[test]
fun album_link_has_no_track_id() {
    let link = amazon_music::new_album(b"B0DY8QZN9H".to_string());
    let data = link.data();
    assert!(data.album_id() == b"B0DY8QZN9H".to_string());
    assert!(data.track_id().is_none());
}

#[test]
fun track_link_carries_track_id() {
    let link = amazon_music::new_track(b"B076YSK8CS".to_string(), b"B076YT2CBT".to_string());
    assert!(link.data().track_id() == option::some(b"B076YT2CBT".to_string()));
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_amazon_music::release_dsp_link_amazon_music)] // EEmptyIdentifier
fun rejects_empty_album_id() {
    let _ = amazon_music::new_album(b"".to_string());
    abort
}
