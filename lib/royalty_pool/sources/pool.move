// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Generic accumulator-based royalty distribution pool.
///
/// A `RoyaltyPool<Share, Currency>` is a derived object of any UID-bearing
/// parent. Its address is deterministically derived from `(parent_id, Currency)`
/// — at most one pool per `(parent, Currency)` pair. The `Share` phantom
/// identifies which share-token type can stake against the pool.
///
/// Holders create a `Stake<Share>` (see `royalty_pool::stake`) and register
/// it. Callers fund the pool by handing it a `Balance<Currency>` via
/// `deposit`; the accumulator advances and claims pay out the per-stake
/// proportional share since each stake's last claim.
///
/// `receive_and_deposit` and `redeem_and_deposit` exist as recovery valves
/// for funds that land directly at the pool's address — either pending
/// `Coin<Currency>` transfers or balances credited to the pool's
/// funds-accumulator. Both are permissionless: anyone who notices stuck
/// funds can fold them in. The canonical funding path remains
/// `deposit(balance)` from a higher-layer extension (e.g.
/// `composition_royalty_distributor`) that pulls from the parent's address.
module royalty_pool::pool;

use hikida::hikida;
use royalty_pool::stake::{Self, Stake};
use std::{type_name, u128};
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::derived_object::{claim, derive_address};
use sui::event::emit;
use sui::transfer::Receiving;

// === Structs ===

public struct RoyaltyPool<phantom Share, phantom Currency> has key {
    id: UID,
    balance: Balance<Currency>,
    staked_shares: u64,
    cumulative_reward_per_share: u256,
    /// Lifetime sum of every deposited value, in currency base units.
    /// Read-only analytics — never decremented; not used by any on-chain logic.
    cumulative_deposits: u128,
}

/// Key used to derive a pool's object ID from its parent UID.
///
/// Phantom-typed: the `Currency` is encoded in the BCS type tag, so the
/// struct itself is empty and zero-cost. `Share` is intentionally not encoded
/// — callers are expected to keep a 1:1 correspondence between the parent
/// type and the pool's `Share` phantom.
public struct RoyaltyPoolKey<phantom Currency>() has copy, drop, store;

// === Events ===

public struct RoyaltyPoolCreatedEvent<phantom Share, phantom Currency> has copy, drop {
    pool_id: ID,
    parent_id: ID,
}

public struct RoyaltyDepositedEvent<phantom Share, phantom Currency> has copy, drop {
    pool_id: ID,
    value: u64,
}

public struct StakeRegisteredEvent<phantom Share, phantom Currency> has copy, drop {
    pool_id: ID,
    stake_id: ID,
    staked_amount: u64,
}

public struct StakeUnregisteredEvent<phantom Share, phantom Currency> has copy, drop {
    pool_id: ID,
    stake_id: ID,
    unstaked_amount: u64,
}

public struct RoyaltyClaimedEvent<phantom Share, phantom Currency> has copy, drop {
    pool_id: ID,
    stake_id: ID,
    reward_amount: u64,
}

// === Constants ===

const PRECISION: u128 = 1_000_000_000_000_000_000;

// === Errors ===

const EPoolNotDerivedFromParent: u64 = 0;
const ENoStakedShares: u64 = 1;
const EAlreadyRegistered: u64 = 2;
const ENotRegistered: u64 = 3;
const EPoolIdMismatch: u64 = 4;
const ELastClaimIndexMismatch: u64 = 5;
const EInvalidValue: u64 = 6;

// === Constructors ===

/// Construct a pool as a derived object of `parent`. The derivation key
/// includes only the `Currency` `TypeName`, so the pool's address is
/// determined entirely by `(parent_id, Currency)`.
///
/// Cap-gating happens at the parent: callers must obtain `&mut UID` via
/// whatever cap-gated accessor the parent exposes.
public fun new<Share, Currency>(parent: &mut UID): RoyaltyPool<Share, Currency> {
    let parent_id = parent.to_inner();
    let pool = RoyaltyPool<Share, Currency> {
        id: claim(parent, RoyaltyPoolKey<Currency>()),
        balance: balance::zero(),
        staked_shares: 0,
        cumulative_reward_per_share: 0,
        cumulative_deposits: 0,
    };

    emit(RoyaltyPoolCreatedEvent<Share, Currency> {
        pool_id: pool.id(),
        parent_id,
    });

    pool
}

/// Share the pool object so holders can register and claim against it.
public fun share<Share, Currency>(self: RoyaltyPool<Share, Currency>) {
    transfer::share_object(self);
}

// === Deposit ===

/// Fold a balance into the accumulator. Aborts on zero staked shares (the
/// deposit would be unattributable) or zero value (no-op deposits are
/// rejected to keep events meaningful).
///
/// Callers obtain the `Balance<Currency>` however they like — typically by
/// pulling from a parent's pending coins or funds accumulator (see e.g.
/// `composition_royalty_distributor`).
public fun deposit<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    balance: Balance<Currency>,
) {
    assert!(self.staked_shares > 0, ENoStakedShares);

    let value = balance.value();
    assert!(value > 0, EInvalidValue);

    let reward_per_share = u128::mul_div(value as u128, PRECISION, self.staked_shares as u128);
    self.cumulative_reward_per_share = self.cumulative_reward_per_share + (reward_per_share as u256);
    self.cumulative_deposits = self.cumulative_deposits + (value as u128);
    self.balance.join(balance);

    emit(RoyaltyDepositedEvent<Share, Currency> {
        pool_id: self.id(),
        value,
    });
}

/// Receive `Coin<Currency>` objects sent directly to this pool's address
/// and fold them into the accumulator. Recovery path for funds delivered to
/// the pool's address rather than via the canonical extension path.
public fun receive_and_deposit<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    coins: vector<Receiving<Coin<Currency>>>,
) {
    let balance = hikida::receive_balance(&mut self.id, coins);
    self.deposit(balance);
}

/// Redeem `value` base units from the pool's funds-accumulator and fold
/// them into the accumulator. Recovery path for funds delivered via Sui's
/// `send_funds` mechanism rather than via the canonical extension path.
public fun redeem_and_deposit<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    value: u64,
) {
    let balance = hikida::redeem_balance<Currency>(&mut self.id, value);
    self.deposit(balance);
}

// === Stake registration ===

/// Register a stake with the pool. Records the stake's entry index so future
/// deposits accrue to it proportionally.
///
/// Aborts if the stake is already registered with a pool of the same Currency.
public fun register_stake<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    stake: &mut Stake<Share>,
) {
    let currency = type_name::with_defining_ids<Currency>();
    assert!(!stake.has_registration(&currency), EAlreadyRegistered);

    let pool_id = self.id();
    let stake_id = stake.id();
    let staked_amount = stake.value();
    let cumulative = self.cumulative_reward_per_share;

    stake.add_registration(currency, stake::new_registration(pool_id, cumulative));
    self.staked_shares = self.staked_shares + staked_amount;

    emit(StakeRegisteredEvent<Share, Currency> {
        pool_id,
        stake_id,
        staked_amount,
    });
}

/// Unregister a stake from the pool. All claimable rewards must be drained
/// first — i.e., a final `claim_rewards` call must yield 0. Sub-base-unit
/// residue in `last_claim_index` (left by the consumed-index advance when a
/// reward truncated to 0) does NOT block unregister, since that residue
/// could never be claimed as a whole base unit anyway. Forfeiting it on
/// exit is the deliberate semantics.
public fun unregister_stake<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    stake: &mut Stake<Share>,
) {
    let currency = type_name::with_defining_ids<Currency>();
    assert!(stake.has_registration(&currency), ENotRegistered);

    let pool_id = self.id();
    let stake_id = stake.id();
    let staked_amount = stake.value();
    let cumulative = self.cumulative_reward_per_share;

    let registration = stake.get_registration(&currency);
    assert!(stake::registration_pool_id(registration) == pool_id, EPoolIdMismatch);
    let last_claim_index = stake::registration_last_claim_index(registration);
    assert!(
        calculate_reward(staked_amount, last_claim_index, cumulative) == 0,
        ELastClaimIndexMismatch,
    );

    stake.remove_registration(&currency);
    self.staked_shares = self.staked_shares - staked_amount;

    emit(StakeUnregisteredEvent<Share, Currency> {
        pool_id,
        stake_id,
        unstaked_amount: staked_amount,
    });
}

// === Claim ===

/// Claim accrued rewards for a registered stake. Advances the stake's
/// `last_claim_index` to the pool's current accumulator.
public fun claim_rewards<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    stake: &mut Stake<Share>,
): Balance<Currency> {
    let currency = type_name::with_defining_ids<Currency>();
    assert!(stake.has_registration(&currency), ENotRegistered);

    let pool_id = self.id();
    let stake_id = stake.id();
    let staked_amount = stake.value();
    let cumulative = self.cumulative_reward_per_share;

    let registration = stake.registration_mut(&currency);
    assert!(stake::registration_pool_id(registration) == pool_id, EPoolIdMismatch);

    let last_claim_index = stake::registration_last_claim_index(registration);
    let reward_amount = calculate_reward(staked_amount, last_claim_index, cumulative);

    // Advance `last_claim_index` only by the index delta the reward consumed,
    // not by the full `(cumulative - last_claim_index)` delta. This preserves
    // sub-base-unit credit for fractional holders whose per-claim reward
    // truncated to 0 — they recover their full proportional share over time.
    let consumed = u128::mul_div(reward_amount as u128, PRECISION, staked_amount as u128);
    stake::set_last_claim_index(registration, last_claim_index + (consumed as u256));

    emit(RoyaltyClaimedEvent<Share, Currency> {
        pool_id,
        stake_id,
        reward_amount,
    });

    self.balance.split(reward_amount)
}

/// Compute pending rewards for a stake without claiming. Returns 0 if the
/// stake is not registered with this pool.
public fun pending_rewards<Share, Currency>(
    self: &RoyaltyPool<Share, Currency>,
    stake: &Stake<Share>,
): u64 {
    let currency = type_name::with_defining_ids<Currency>();

    if (!stake.has_registration(&currency)) {
        return 0
    };

    let registration = stake.get_registration(&currency);
    if (stake::registration_pool_id(registration) != self.id()) {
        return 0
    };

    calculate_reward(
        stake.value(),
        stake::registration_last_claim_index(registration),
        self.cumulative_reward_per_share,
    )
}

// === Public View Functions ===

public fun id<Share, Currency>(self: &RoyaltyPool<Share, Currency>): ID {
    self.id.to_inner()
}

public fun balance<Share, Currency>(self: &RoyaltyPool<Share, Currency>): &Balance<Currency> {
    &self.balance
}

public fun staked_shares<Share, Currency>(self: &RoyaltyPool<Share, Currency>): u64 {
    self.staked_shares
}

public fun cumulative_reward_per_share<Share, Currency>(
    self: &RoyaltyPool<Share, Currency>,
): u256 {
    self.cumulative_reward_per_share
}

/// Lifetime sum of all deposits, in currency base units. Strictly monotonic.
public fun cumulative_deposits<Share, Currency>(
    self: &RoyaltyPool<Share, Currency>,
): u128 {
    self.cumulative_deposits
}

/// Compute the deterministic address of a pool given its parent ID and
/// `Currency` type parameter. Useful for off-chain derivation and for
/// cross-module checks that the pool was minted from the expected parent.
public fun derived_address<Currency>(parent_id: ID): address {
    derive_address(parent_id, RoyaltyPoolKey<Currency>())
}

/// Read-only verification that the pool was derived from the given parent ID.
public fun assert_derived_from<Share, Currency>(
    self: &RoyaltyPool<Share, Currency>,
    parent_id: ID,
) {
    assert!(
        self.id.to_address() == derive_address(parent_id, RoyaltyPoolKey<Currency>()),
        EPoolNotDerivedFromParent,
    );
}

// === Private Functions ===

fun calculate_reward(staked_amount: u64, last_claim_index: u256, current_index: u256): u64 {
    let reward_delta = current_index - last_claim_index;
    let reward = (staked_amount as u256) * reward_delta / (PRECISION as u256);
    (reward as u64)
}
