// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module per_track::per_track_tests;

// Alias the module so the bare address `per_track` resolves in
// `#[expected_failure(location = per_track::per_track)]` (avoids the
// addr==module name collision).
use per_track::per_track as pt;

// `new`/`filled` read a `Release` to enforce tracklist alignment; that
// release-bound path is exercised by the consuming extensions' tests. Here we
// unit-test the index/bounds logic via the test-only bypass constructor.

#[test]
fun length_and_borrow() {
    let entries = pt::from_entries_for_testing(vector[10u64, 20, 30]);
    assert!(entries.length() == 3);
    assert!(*entries.borrow(0) == 10);
    assert!(*entries.borrow(2) == 30);
}

#[test]
fun borrow_mut_replaces_entry() {
    let mut entries = pt::from_entries_for_testing(vector[1u64, 2, 3]);
    *entries.borrow_mut(1) = 99;
    assert!(*entries.borrow(1) == 99);
}

#[test]
fun empty_has_zero_length() {
    let entries = pt::from_entries_for_testing<u64>(vector[]);
    assert!(entries.length() == 0);
}

#[test, expected_failure(abort_code = 0, location = per_track::per_track)] // EIndexOutOfBounds
fun borrow_past_end_aborts() {
    let entries = pt::from_entries_for_testing(vector[1u64]);
    entries.borrow(5);
}

#[test, expected_failure(abort_code = 0, location = per_track::per_track)] // EIndexOutOfBounds
fun borrow_mut_past_end_aborts() {
    let mut entries = pt::from_entries_for_testing(vector[1u64]);
    entries.borrow_mut(5);
}
