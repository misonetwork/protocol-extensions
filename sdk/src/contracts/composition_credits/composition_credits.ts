/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * First-party credits extension for compositions.
 * 
 * Attribution (writing credits) is display-oriented and varies across platforms,
 * so it lives here as a dynamic field on the composition rather than in immutable
 * core. The data is attached under `CompositionCreditsKey()` via the composition's
 * cap-gated `uid_mut`, so every mutation is authorized by the composition's admin
 * and credits survive into any lifecycle state (they may be attached before or
 * after the composition is published).
 * 
 * This is Miso's canonical credits standard; because it is an extension, other
 * parties may publish their own composition-credits standard against the same
 * `Composition`. Credits are NOT read by the economics — they are attribution.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as vec_map from './deps/sui/vec_map.js';
import * as credit from './deps/partyos/credit.js';
import * as composition_party_role from './composition_party_role.js';
const $moduleName = '@local-pkg/composition_credits::composition_credits';
export const CompositionCreditsKey = new MoveTuple({ name: `${$moduleName}::CompositionCreditsKey`, fields: [bcs.bool()] });
export const CompositionCredits = new MoveStruct({ name: `${$moduleName}::CompositionCredits`, fields: {
        /** Map of party IDs to their credit (display name + roles). */
        credits: vec_map.VecMap(bcs.Address, credit.Credit(composition_party_role.CompositionPartyRole))
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
    typeArguments: [
        string
    ];
}
/**
 * Adds a credit for a party on the composition, lazily creating the credits record
 * on first use. Each credit must have 1-5 roles, and a party may hold at most one
 * credit. Requires the composition's admin capability.
 */
export function addCredit(options: AddCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "party", "credit"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_credits',
        function: 'add_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
    ];
}
/** Removes a party's credit. Requires the composition's admin capability. */
export function removeCredit(options: RemoveCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    const argumentsTypes = [
        null,
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_credits',
        function: 'remove_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
    ];
}
/** Returns whether a credits record has been attached to this composition yet. */
export function hasCredits(options: HasCreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_credits',
        function: 'has_credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string
    ];
}
/** Returns the party-to-credit map. Aborts if no credits are attached. */
export function credits(options: CreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_credits',
        function: 'credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}