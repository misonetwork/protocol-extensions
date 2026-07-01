// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_soundcloud::release_dsp_link_soundcloud_tests;

use release_dsp_link_soundcloud::release_dsp_link_soundcloud as soundcloud;

#[test]
fun wraps_user_and_slug() {
    let link = soundcloud::new(b"artist".to_string(), b"my-ep".to_string());
    let data = link.data();
    assert!(data.user() == b"artist".to_string());
    assert!(data.slug() == b"my-ep".to_string());
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_soundcloud::release_dsp_link_soundcloud)] // EEmptyIdentifier
fun rejects_empty_slug() {
    let _ = soundcloud::new(b"artist".to_string(), b"".to_string());
    abort
}
