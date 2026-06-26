/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the roles that parties can hold on a release. Releases are the
 * commercial packaging of recordings (an album, single, EP), and a release credit
 * captures top-line billing: a party is either a primary artist or a featured
 * artist on the release.
 * 
 * ### Design
 * 
 * `ReleasePartyRole` is a closed enum: variants can only be constructed and
 * matched inside this module, so the `new_*_role` constructors are the external
 * write-API and `name()` is the external read-API.
 * 
 * - **No level axis and no `Custom` escape hatch.** Release billing is a small,
 *   fixed vocabulary: `Primary` or `Featured`.
 * - **`name()` is the canonical identifier**, returned as a stable PascalCase
 *   token (`"Primary"` / `"Featured"`).
 * 
 * These identifiers are Miso's own canonical vocabulary; any overlap with an
 * external standard (e.g. DDEX) is coincidental, not a reproduction of it.
 */

import { MoveEnum, normalizeMoveArguments } from '../utils/index.js';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/release_credits::release_party_role';
/** Represents a party's billing on a release. */
export const ReleasePartyRole = new MoveEnum({ name: `${$moduleName}::ReleasePartyRole`, fields: {
        /** A primary (headline) artist on the release. */
        Primary: null,
        /** A featured (guest) artist on the release. */
        Featured: null
    } });
export interface NewPrimaryRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Primary role. */
export function newPrimaryRole(options: NewPrimaryRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'new_primary_role',
    });
}
export interface NewFeaturedRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Featured role. */
export function newFeaturedRole(options: NewFeaturedRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'new_featured_role',
    });
}
export interface NameArguments {
    self: TransactionArgument;
}
export interface NameOptions {
    package?: string;
    arguments: NameArguments | [
        self: TransactionArgument
    ];
}
/** Returns the canonical identifier of the role as a stable PascalCase token. */
export function name(options: NameOptions) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_party_role',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}