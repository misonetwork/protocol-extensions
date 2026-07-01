// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_youtube_music::release_dsp_link_youtube_music_tests;

use release_dsp_link_youtube_music::release_dsp_link_youtube_music as youtube_music;

#[test]
fun wraps_id() {
    let link = youtube_music::new(b"OLAK5uy_k123".to_string());
    assert!(link.data().id() == b"OLAK5uy_k123".to_string());
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_youtube_music::release_dsp_link_youtube_music)] // EEmptyId
fun rejects_empty_id() {
    let _ = youtube_music::new(b"".to_string());
    abort
}
