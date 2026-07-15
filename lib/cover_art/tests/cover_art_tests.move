// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module cover_art::cover_art_tests;

use cover_art::cover_art;
use ori::walrus_data;

#[test]
fun new_still_only() {
    let art = cover_art::new(walrus_data::new_blob(1), option::none());
    assert!(art.still().blob_id() == 1);
    assert!(art.animated().is_none());
}

#[test]
fun new_with_animation() {
    let art = cover_art::new(walrus_data::new_blob(1), option::some(walrus_data::new_blob(2)));
    assert!(art.animated().is_some());
    assert!(art.animated().borrow().blob_id() == 2);
}

// `new` requires the still image to be a Walrus blob; a quilt patch is rejected
// by `assert_is_blob`, which aborts in `ori::walrus_data`.
#[test, expected_failure(abort_code = 0, location = ori::walrus_data)] // ENotBlob
fun new_rejects_non_blob_still() {
    cover_art::new(walrus_data::new_quilt_patch(1, 0, 0, 1), option::none());
}
