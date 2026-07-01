// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_tidal::release_dsp_link_tidal_tests;

use release_dsp_link_tidal::release_dsp_link_tidal as tidal;

#[test]
fun wraps_id() {
    let link = tidal::new(b"419980975".to_string());
    assert!(link.data().id() == b"419980975".to_string());
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_tidal::release_dsp_link_tidal)] // EEmptyId
fun rejects_empty_id() {
    let _ = tidal::new(b"".to_string());
    abort
}
