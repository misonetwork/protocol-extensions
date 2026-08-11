// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module release_credits::credits_tests;

use miso::release::{Self, Release, ReleaseAdminCap};
use miso_credit::credit;
use partyos::party::{Self, Party, PartyAdminCap};
use release_credits::release_credits as credits;
use release_credits::release_party_role as rpr;
use std::unit_test::{assert_eq, destroy};
use sui::event;
use sui::test_scenario;

const ARTIST: address = @0xA1;

fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    release::new_for_testing(b"Album".to_string(), vector[], ctx)
}

fun mk_party(name: vector<u8>, ctx: &mut TxContext): (Party, PartyAdminCap) {
    let clock = sui::clock::create_for_testing(ctx);
    let (party, cap) = party::new(party::new_individual_kind(), name.to_string(), &clock, ctx);
    clock.destroy_for_testing();
    (party, cap)
}

#[test]
fun add_credit_attaches_and_reads_back() {
    let mut ts = test_scenario::begin(ARTIST);
    let (mut rel, cap) = mk_release(ts.ctx());
    assert!(!credits::has_credits(&rel));

    let (p1, p1c) = mk_party(b"Alice", ts.ctx());
    credits::add_credit(
        &mut rel,
        &cap,
        &p1,
        credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]),
    );

    assert!(credits::has_credits(&rel));
    assert_eq!(credits::credits(&rel).length(), 1);

    let (p2, p2c) = mk_party(b"Bob", ts.ctx());
    credits::add_credit(
        &mut rel,
        &cap,
        &p2,
        credit::new(b"Bob".to_string(), vector[rpr::new_featured_role()]),
    );
    assert_eq!(credits::credits(&rel).length(), 2);

    destroy(rel); destroy(cap); destroy(p1); destroy(p1c); destroy(p2); destroy(p2c);
    ts.end();
}

#[test, expected_failure(abort_code = 40, location = release_credits::release_credits)] // EPartyAlreadyCredited
fun add_credit_rejects_duplicate_party() {
    let mut ts = test_scenario::begin(ARTIST);
    let (mut rel, cap) = mk_release(ts.ctx());
    let (p, _pc) = mk_party(b"Alice", ts.ctx());
    credits::add_credit(
        &mut rel,
        &cap,
        &p,
        credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]),
    );
    credits::add_credit(
        &mut rel,
        &cap,
        &p,
        credit::new(b"Alice".to_string(), vector[rpr::new_featured_role()]),
    );
    abort
}

#[test, expected_failure(abort_code = 53, location = release_credits::release_credits)] // EInvalidCreditRoleCount
fun add_credit_rejects_multiple_roles() {
    let mut ts = test_scenario::begin(ARTIST);
    let (mut rel, cap) = mk_release(ts.ctx());
    let (p, _pc) = mk_party(b"Alice", ts.ctx());
    credits::add_credit(
        &mut rel,
        &cap,
        &p,
        credit::new(b"Alice".to_string(), vector[
            rpr::new_primary_role(),
            rpr::new_featured_role(), // 2 != CREDIT_ROLE_COUNT (1)
        ]),
    );
    abort
}

#[test]
fun remove_credit_round_trip() {
    let mut ts = test_scenario::begin(ARTIST);
    let (mut rel, cap) = mk_release(ts.ctx());
    let (p, _pc) = mk_party(b"Alice", ts.ctx());
    let pid = p.id();
    credits::add_credit(
        &mut rel,
        &cap,
        &p,
        credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]),
    );
    assert_eq!(credits::credits(&rel).length(), 1);

    credits::remove_credit(&mut rel, &cap, pid);
    assert_eq!(credits::credits(&rel).length(), 0);

    destroy(rel); destroy(cap); destroy(p); destroy(_pc);
    ts.end();
}

#[test]
fun add_credit_emits_the_full_record() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);
    let (p1, p1c) = mk_party(b"Alice", ctx);
    let (p2, p2c) = mk_party(b"Bob", ctx);

    credits::add_credit(
        &mut rel,
        &cap,
        &p1,
        credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]),
    );
    credits::add_credit(
        &mut rel,
        &cap,
        &p2,
        credit::new(b"Bob".to_string(), vector[rpr::new_featured_role()]),
    );

    let events = event::events_by_type<credits::CreditAddedEvent>();
    assert_eq!(events.length(), 2);

    let (release_id, party_id, credit) = credits::added_event_fields(&events[0]);
    assert_eq!(release_id, rel_id);
    assert_eq!(party_id, p1.id());
    assert_eq!(credit, credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]));

    let (release_id, party_id, credit) = credits::added_event_fields(&events[1]);
    assert_eq!(release_id, rel_id);
    assert_eq!(party_id, p2.id());
    assert_eq!(credit, credit::new(b"Bob".to_string(), vector[rpr::new_featured_role()]));

    destroy(rel); destroy(cap); destroy(p1); destroy(p1c); destroy(p2); destroy(p2c);
}

#[test]
fun remove_credit_emits_the_removed_record() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = mk_release(ctx);
    let rel_id = object::id(&rel);
    let (p, pc) = mk_party(b"Alice", ctx);
    let pid = p.id();

    credits::add_credit(
        &mut rel,
        &cap,
        &p,
        credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]),
    );
    credits::remove_credit(&mut rel, &cap, pid);

    let events = event::events_by_type<credits::CreditRemovedEvent>();
    assert_eq!(events.length(), 1);
    let (release_id, party_id, credit) = credits::removed_event_fields(&events[0]);
    assert_eq!(release_id, rel_id);
    assert_eq!(party_id, pid);
    assert_eq!(credit, credit::new(b"Alice".to_string(), vector[rpr::new_primary_role()]));

    destroy(rel); destroy(cap); destroy(p); destroy(pc);
}
