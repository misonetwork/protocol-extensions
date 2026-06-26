// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Cap-gated royalty-pool extension for `Composition`.
///
/// Royalty payers send `Coin<Currency>` directly to the composition's
/// address — a stable, well-known inbox available from the composition's
/// creation. The composition admin (cap holder) folds those funds into the
/// underlying `royalty_pool::pool::RoyaltyPool` via `receive_and_deposit`
/// (for direct coin transfers) or `redeem_and_deposit` (for
/// funds-accumulator balances).
///
/// All three entry points require `&CompositionAdminCap`, so timing of
/// fold operations stays under admin control.
module composition_royalty_pool::composition_royalty_pool;

use hikida::hikida;
use miso::composition::{Composition, CompositionAdminCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use sui::coin::Coin;
use sui::transfer::Receiving;

// === Errors ===

const EPoolNotForComposition: u64 = 0;

// === Public Functions ===

/// Create a royalty pool for a composition. Pool address derives from
/// `(composition_id, Currency)` — calling twice with the same Currency
/// aborts because the address is already claimed.
public fun initialize_pool<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
): RoyaltyPool<CompositionShare, Currency> {
    pool::new(composition.uid_mut(cap))
}

/// Receive `Coin<Currency>` objects sent to the composition's address and
/// fold them into the pool's accumulator.
public fun receive_and_deposit<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    coins: vector<Receiving<Coin<Currency>>>,
    pool: &mut RoyaltyPool<CompositionShare, Currency>,
) {
    assert_pool_for_composition(pool, composition.id());
    let balance = hikida::receive_balance(composition.uid_mut(cap), coins);
    pool.deposit(balance);
}

/// Redeem `value` base units from the composition's funds accumulator and
/// fold the resulting balance into the pool's accumulator.
public fun redeem_and_deposit<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    value: u64,
    pool: &mut RoyaltyPool<CompositionShare, Currency>,
) {
    assert_pool_for_composition(pool, composition.id());
    let balance = hikida::redeem_balance<Currency>(composition.uid_mut(cap), value);
    pool.deposit(balance);
}

// === Private Functions ===

/// Verify the pool was derived from the given composition. Prevents
/// accidentally folding one composition's revenue into another's pool.
fun assert_pool_for_composition<CompositionShare, Currency>(
    pool: &RoyaltyPool<CompositionShare, Currency>,
    composition_id: ID,
) {
    assert!(
        pool.id().to_address() == pool::derived_address<Currency>(composition_id),
        EPoolNotForComposition,
    );
}
