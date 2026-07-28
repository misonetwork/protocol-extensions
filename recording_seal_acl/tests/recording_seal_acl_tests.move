// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_seal_acl::recording_seal_acl_tests;

use miso::recording::{Self, Recording, RecordingAdminCap};
use recording_seal_acl::acl;
use std::string::String;
use std::unit_test::destroy;
use sui::bcs;
use sui::clock::{Self, Clock};
use sui::test_scenario;
use suins::domain;
use suins::registry::{Self, Registry};
use suins::suins::{Self, SuiNS};
use suins::suins_registration::SuinsRegistration;

// Mirror acl's error codes for expected_failure assertions.
const EWrongRecording: u64 = 50;
const EMalformedId: u64 = 51;
const ENoAccess: u64 = 52;

const ARTIST: address = @0xa57;
const DELIVERY: address = @0xde11;
const RANDO: address = @0x123;

// Phantom marker types for the share parameters.
public struct REC {}
public struct COMP {}

/// Test app authorized to mutate the SuiNS registry in fixtures.
public struct TestApp() has drop;

fun leaf_name(): String { b"delivery.miso.sui".to_string() }

fun digest(): vector<u8> { x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20" }

/// SuiNS with `miso.sui` registered and leaf `delivery.miso.sui` targeting
/// `DELIVERY`, plus a recording and its admin cap.
fun setup(
    ctx: &mut TxContext,
): (SuiNS, Clock, SuinsRegistration, Recording<REC, COMP>, RecordingAdminCap<REC>) {
    let (mut suins, admin_cap) = suins::new_for_testing(ctx);
    suins::add_registry(&admin_cap, &mut suins, registry::new(&admin_cap, ctx));
    suins.authorize_app_for_testing<TestApp>();
    let clock = clock::create_for_testing(ctx);

    let reg = suins::app_registry_mut<TestApp, Registry>(TestApp(), &mut suins);
    let parent = reg.add_record(domain::new(b"miso.sui".to_string()), 1, &clock, ctx);
    reg.add_leaf_record(domain::new(leaf_name()), &clock, DELIVERY, ctx);
    destroy(admin_cap);

    let (rec, rec_cap) = recording::new_for_testing<REC, COMP>(b"Take 1".to_string(), ctx);
    (suins, clock, parent, rec, rec_cap)
}

fun cleanup(
    suins: SuiNS,
    clock: Clock,
    parent: SuinsRegistration,
    rec: Recording<REC, COMP>,
    rec_cap: RecordingAdminCap<REC>,
    scenario: test_scenario::Scenario,
) {
    destroy(suins);
    destroy(clock);
    destroy(parent);
    destroy(rec);
    destroy(rec_cap);
    scenario.end();
}

/// Builds the Seal identity `[recording_id ‖ pcm_digest]` for a recording.
fun identity(rec: &Recording<REC, COMP>): vector<u8> {
    let mut id = rec.id().to_address().to_bytes();
    id.append(bcs::to_bytes(&digest()));
    id
}

// === seal_approve (address grants) ===

#[test]
fun address_grant_lets_grantee_approve() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_address(&mut rec, &rec_cap, DELIVERY);
    assert!(acl::is_address_authorized(&rec, DELIVERY));

    // The key server dry-runs seal_approve with the grantee as sender.
    scenario.next_tx(DELIVERY);
    acl::seal_approve(identity(&rec), &rec, scenario.ctx());

    destroy(suins);
    destroy(clock);
    destroy(parent);
    destroy(rec);
    destroy(rec_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = ENoAccess, location = recording_seal_acl::acl)]
fun ungranted_sender_cannot_approve() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_address(&mut rec, &rec_cap, DELIVERY);

    scenario.next_tx(RANDO);
    acl::seal_approve(identity(&rec), &rec, scenario.ctx());
    cleanup(suins, clock, parent, rec, rec_cap, scenario); // unreachable
}

#[test, expected_failure(abort_code = ENoAccess, location = recording_seal_acl::acl)]
fun revoked_address_cannot_approve() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_address(&mut rec, &rec_cap, DELIVERY);
    acl::revoke_address(&mut rec, &rec_cap, DELIVERY);

    scenario.next_tx(DELIVERY);
    acl::seal_approve(identity(&rec), &rec, scenario.ctx());
    cleanup(suins, clock, parent, rec, rec_cap, scenario); // unreachable
}

// === seal_approve_name (SuiNS name grants) ===

#[test]
fun name_grant_lets_current_target_approve() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_name(&mut rec, &rec_cap, leaf_name(), &suins);
    assert!(acl::is_name_authorized(&rec, leaf_name(), &suins, DELIVERY));

    scenario.next_tx(DELIVERY);
    acl::seal_approve_name(identity(&rec), &rec, leaf_name(), &suins, scenario.ctx());

    destroy(suins);
    destroy(clock);
    destroy(parent);
    destroy(rec);
    destroy(rec_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = ENoAccess, location = recording_seal_acl::acl)]
fun name_grant_denies_non_target_sender() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_name(&mut rec, &rec_cap, leaf_name(), &suins);

    // RANDO claims the granted name but the name does not target them.
    scenario.next_tx(RANDO);
    acl::seal_approve_name(identity(&rec), &rec, leaf_name(), &suins, scenario.ctx());
    cleanup(suins, clock, parent, rec, rec_cap, scenario); // unreachable
}

#[test, expected_failure(abort_code = ENoAccess, location = recording_seal_acl::acl)]
fun revoked_name_cannot_approve() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_name(&mut rec, &rec_cap, leaf_name(), &suins);
    acl::revoke_name(&mut rec, &rec_cap, leaf_name());

    scenario.next_tx(DELIVERY);
    acl::seal_approve_name(identity(&rec), &rec, leaf_name(), &suins, scenario.ctx());
    cleanup(suins, clock, parent, rec, rec_cap, scenario); // unreachable
}

// === Identity binding ===

#[test, expected_failure(abort_code = EWrongRecording, location = recording_seal_acl::acl)]
fun identity_bound_to_other_recording_aborts() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());
    let (other, other_cap) = recording::new_for_testing<REC, COMP>(b"Take 2".to_string(), scenario.ctx());

    acl::grant_address(&mut rec, &rec_cap, DELIVERY);

    // Identity names the other recording; the policy must reject it.
    scenario.next_tx(DELIVERY);
    acl::seal_approve(identity(&other), &rec, scenario.ctx());
    // Unreachable; satisfies the ability checker.
    destroy(other);
    destroy(other_cap);
    cleanup(suins, clock, parent, rec, rec_cap, scenario);
}

#[test, expected_failure(abort_code = EMalformedId, location = recording_seal_acl::acl)]
fun identity_with_trailing_bytes_aborts() {
    let mut scenario = test_scenario::begin(ARTIST);
    let (suins, clock, parent, mut rec, rec_cap) = setup(scenario.ctx());

    acl::grant_address(&mut rec, &rec_cap, DELIVERY);

    let mut id = identity(&rec);
    id.push_back(0xff);

    scenario.next_tx(DELIVERY);
    acl::seal_approve(id, &rec, scenario.ctx());
    cleanup(suins, clock, parent, rec, rec_cap, scenario); // unreachable
}
