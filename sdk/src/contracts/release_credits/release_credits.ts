/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * First-party credits extension for releases.
 * 
 * Attribution (top-line billing) is display-oriented and varies across platforms,
 * so it lives here as a dynamic field on the release rather than in immutable
 * core. The data is attached under `ReleaseCreditsKey()` via the release's
 * cap-gated `uid_mut`, so every mutation is authorized by the release's admin and
 * credits survive into any lifecycle state (they may be attached before or after
 * the release is published).
 * 
 * This is Miso's canonical credits standard; because it is an extension, other
 * parties may publish their own release-credits standard against the same
 * `Release`. Credits are NOT read by the economics — they are attribution.
 * 
 * A release credit carries exactly one role: a party is billed as either a
 * `Primary` or a `Featured` artist on the release.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as vec_map from './deps/sui/vec_map.js';
import * as credit from './deps/partyos/credit.js';
import * as release_party_role from './release_party_role.js';
const $moduleName = '@local-pkg/release_credits::release_credits';
export const ReleaseCreditsKey = new MoveTuple({ name: `${$moduleName}::ReleaseCreditsKey`, fields: [bcs.bool()] });
export const ReleaseCredits = new MoveStruct({ name: `${$moduleName}::ReleaseCredits`, fields: {
        /** Map of party IDs to their credit (display name + role). */
        credits: vec_map.VecMap(bcs.Address, credit.Credit(release_party_role.ReleasePartyRole))
    } });
export interface AddCreditArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
    credit: TransactionArgument;
}
export interface AddCreditOptions {
    package?: string;
    arguments: AddCreditArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>,
        credit: TransactionArgument
    ];
}
/**
 * Adds a credit for a party on the release, lazily creating the credits record on
 * first use. Each credit must carry exactly one role (Primary or Featured), and a
 * party may hold at most one credit. Requires the release's admin capability.
 */
export function addCredit(options: AddCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "party", "credit"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_credits',
        function: 'add_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RemoveCreditArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface RemoveCreditOptions {
    package?: string;
    arguments: RemoveCreditArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
}
/** Removes a party's credit. Requires the release's admin capability. */
export function removeCredit(options: RemoveCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    const argumentsTypes = [
        null,
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_credits',
        function: 'remove_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface HasCreditsArguments {
    self: RawTransactionArgument<string>;
}
export interface HasCreditsOptions {
    package?: string;
    arguments: HasCreditsArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns whether a credits record has been attached to this release yet. */
export function hasCredits(options: HasCreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_credits',
        function: 'has_credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CreditsArguments {
    self: RawTransactionArgument<string>;
}
export interface CreditsOptions {
    package?: string;
    arguments: CreditsArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the party-to-credit map. Aborts if no credits are attached. */
export function credits(options: CreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/release_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_credits',
        function: 'credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}