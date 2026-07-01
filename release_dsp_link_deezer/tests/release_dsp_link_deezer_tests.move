// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_deezer::release_dsp_link_deezer_tests;

use release_dsp_link_deezer::release_dsp_link_deezer as deezer;

#[test]
fun wraps_id() {
    let link = deezer::new(b"718572651".to_string());
    assert!(link.data().id() == b"718572651".to_string());
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_deezer::release_dsp_link_deezer)] // EEmptyId
fun rejects_empty_id() {
    let _ = deezer::new(b"".to_string());
    abort
}
