// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module dsp_link::dsp_link_tests;

// Aliased so the bare `dsp_link` address stays free for `location = ...` below.
use dsp_link::dsp_link as dl;
use sui::test_scenario;

const A: address = @0xA1;

// A throwaway DSP payload — the primitive is generic, so any copy+drop+store
// type exercises it.
public struct FakeData has copy, drop, store {
    v: u64,
}

// A minimal keyed object to hang dynamic fields on.
public struct Holder has key {
    id: UID,
}

#[test]
fun new_and_data() {
    let link = dl::new(FakeData { v: 7 });
    assert!(link.data().v == 7);
}

#[test]
fun uid_storage_roundtrip() {
    let mut ts = test_scenario::begin(A);
    let mut holder = Holder { id: object::new(ts.ctx()) };

    assert!(!dl::exists_<FakeData>(&holder.id));
    assert!(dl::get<FakeData>(&holder.id).is_none());

    dl::set(&mut holder.id, dl::new(FakeData { v: 1 }));
    assert!(dl::exists_<FakeData>(&holder.id));
    assert!(dl::borrow<FakeData>(&holder.id).data().v == 1);

    // `set` replaces the existing value.
    dl::set(&mut holder.id, dl::new(FakeData { v: 2 }));
    assert!(dl::get<FakeData>(&holder.id).destroy_some().data().v == 2);

    let removed = dl::remove<FakeData>(&mut holder.id);
    assert!(removed.data().v == 2);
    assert!(!dl::exists_<FakeData>(&holder.id));

    // `clear` is a no-op when absent.
    dl::clear<FakeData>(&mut holder.id);

    let Holder { id } = holder;
    id.delete();
    ts.end();
}

#[test, expected_failure(abort_code = 0, location = dsp_link::dsp_link)] // ENoLink
fun borrow_aborts_when_absent() {
    let mut ts = test_scenario::begin(A);
    let holder = Holder { id: object::new(ts.ctx()) };
    let _ = dl::borrow<FakeData>(&holder.id);
    abort
}
