// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_spotify::release_dsp_link_spotify_tests;

use release_dsp_link_spotify::release_dsp_link_spotify as spotify;

#[test]
fun wraps_id() {
    let link = spotify::new(b"3xTbtTM3BSRIGxzWSMaEpc".to_string());
    assert!(link.data().id() == b"3xTbtTM3BSRIGxzWSMaEpc".to_string());
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_spotify::release_dsp_link_spotify)] // EEmptyId
fun rejects_empty_id() {
    let _ = spotify::new(b"".to_string());
    abort
}
