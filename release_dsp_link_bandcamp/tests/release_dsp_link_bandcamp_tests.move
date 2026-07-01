// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_dsp_link_bandcamp::release_dsp_link_bandcamp_tests;

use release_dsp_link_bandcamp::release_dsp_link_bandcamp as bandcamp;

#[test]
fun wraps_subdomain_and_slug() {
    let link = bandcamp::new(b"blcksunrecords".to_string(), b"blck-sun".to_string());
    let data = link.data();
    assert!(data.subdomain() == b"blcksunrecords".to_string());
    assert!(data.slug() == b"blck-sun".to_string());
}

#[test, expected_failure(abort_code = 0, location = release_dsp_link_bandcamp::release_dsp_link_bandcamp)] // EEmptyIdentifier
fun rejects_empty_subdomain() {
    let _ = bandcamp::new(b"".to_string(), b"blck-sun".to_string());
    abort
}
