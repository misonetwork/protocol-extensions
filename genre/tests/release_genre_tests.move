// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module genre::release_genre_tests;

use genre::genre as g;
use genre::genre::{GenreRegistry, GenreRegistryCap, Genre};
use genre::release_genre as rg;
use miso::disc;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers;
use miso::track;
use std::unit_test::destroy;
use sui::test_scenario::{Self as ts, Scenario};

const CURATOR: address = @0xC0;

// === Helpers ===

/// Creates a genre in the registry (cap-gated) and returns its derived id.
fun create_genre(scenario: &Scenario, name: vector<u8>): ID {
    let cap = scenario.take_from_sender<GenreRegistryCap>();
    let mut registry = scenario.take_shared<GenreRegistry>();
    let id = g::derive_genre_id(&registry, name.to_string());
    g::new(&cap, &mut registry, name.to_string());
    ts::return_shared(registry);
    scenario.return_to_sender(cap);
    id
}

// A 2-track release (single disc): tracklist indices 0, 1.
fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    let rel_id = test_helpers::fake_id(ctx);
    let r0 = test_helpers::fake_id(ctx);
    let r1 = test_helpers::fake_id(ctx);
    let d = disc::new(
        vector[
            track::new_for_testing(r0, rel_id, 5000),
            track::new_for_testing(r1, rel_id, 5000),
        ],
        option::none(),
    );
    release::new_for_testing(b"Album".to_string(), vector[d], ctx)
}

// === Album-level assignment ===

#[test]
fun set_primary_genre_and_tracks_inherit() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let genre_id = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre = scenario.take_immutable_by_id<Genre>(genre_id);
    let (mut rel, cap) = mk_release(scenario.ctx());

    assert!(!rg::has_genre(&rel));
    rg::set_primary_genre(&mut rel, &cap, &genre, scenario.ctx());
    assert!(rg::has_genre(&rel));
    assert!(rg::primary_genre(&rel) == option::some(genre_id));
    assert!(rg::secondary_genres(&rel).is_empty());
    // With no overrides, every track inherits the album primary.
    assert!(rg::track_primary_genre(&rel, 0) == option::some(genre_id));
    assert!(rg::track_primary_genre(&rel, 1) == option::some(genre_id));

    ts::return_immutable(genre);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
fun replace_primary_after_hold_period() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    // Wait out the 30-epoch hold period, then the change is allowed.
    30u64.do!(|_| { scenario.next_epoch(CURATOR); });
    rg::set_primary_genre(&mut rel, &cap, &genre2, scenario.ctx());
    assert!(rg::primary_genre(&rel) == option::some(g2));

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 31, location = genre::release_genre)] // EPrimaryGenreLocked
fun change_primary_too_soon_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    scenario.next_epoch(CURATOR); // only one epoch — still locked
    rg::set_primary_genre(&mut rel, &cap, &genre2, scenario.ctx());

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
fun add_and_remove_secondary_genres() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&scenario, b"ELECTRONIC");
    scenario.next_tx(CURATOR);
    let g3 = create_genre(&scenario, b"AMBIENT");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let genre3 = scenario.take_immutable_by_id<Genre>(g3);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    rg::add_secondary_genre(&mut rel, &cap, &genre2);
    rg::add_secondary_genre(&mut rel, &cap, &genre3);
    assert!(rg::secondary_genres(&rel) == vector[g2, g3]);

    rg::remove_secondary_genre(&mut rel, &cap, &genre2);
    assert!(rg::secondary_genres(&rel) == vector[g3]);

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    ts::return_immutable(genre3);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 30, location = genre::release_genre)] // ENoPrimaryGenre
fun secondary_before_primary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::add_secondary_genre(&mut rel, &cap, &genre1); // no primary yet

    ts::return_immutable(genre1);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 40, location = genre::release_genre)] // ESecondaryIsPrimary
fun secondary_equal_primary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    rg::add_secondary_genre(&mut rel, &cap, &genre1); // same as primary

    ts::return_immutable(genre1);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 41, location = genre::release_genre)] // EGenreAlreadySecondary
fun duplicate_secondary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    rg::add_secondary_genre(&mut rel, &cap, &genre2);
    rg::add_secondary_genre(&mut rel, &cap, &genre2); // duplicate

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

// === Per-track overrides ===

#[test]
fun track_override_resolves_over_album() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    // Override track 1 to g2; track 0 still inherits the album primary g1.
    rg::set_track_primary_genre(&mut rel, &cap, 1, &genre2);
    assert!(rg::track_primary_genre(&rel, 0) == option::some(g1));
    assert!(rg::track_primary_genre(&rel, 1) == option::some(g2));

    // Clear the override; track 1 falls back to the album primary.
    rg::unset_track_primary_genre(&mut rel, &cap, 1);
    assert!(rg::track_primary_genre(&rel, 1) == option::some(g1));

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 30, location = genre::release_genre)] // ENoPrimaryGenre
fun track_override_before_primary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_track_primary_genre(&mut rel, &cap, 0, &genre1); // no album primary yet

    ts::return_immutable(genre1);
    destroy(rel);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 50, location = genre::release_genre)] // ETrackIndexOutOfBounds
fun track_override_out_of_bounds_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let (mut rel, cap) = mk_release(scenario.ctx());

    rg::set_primary_genre(&mut rel, &cap, &genre1, scenario.ctx());
    rg::set_track_primary_genre(&mut rel, &cap, 2, &genre1); // 2 tracks → index 2 invalid

    ts::return_immutable(genre1);
    destroy(rel);
    destroy(cap);
    scenario.end();
}
