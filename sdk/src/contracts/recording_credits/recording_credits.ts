/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * First-party credits extension for recordings.
 * 
 * Attribution (credits + primary/featured artists) is display-oriented and varies
 * across platforms, so it lives here as a dynamic field on the recording rather
 * than in immutable core. The data is attached under `RecordingCreditsKey()` via
 * the recording's cap-gated `uid_mut`, so every mutation is authorized by the
 * recording's admin and credits survive into any lifecycle state (they may be
 * attached before or after the recording is published).
 * 
 * This is Miso's canonical credits standard; because it is an extension, other
 * parties may publish their own recording-credits standard against the same
 * `Recording`. Credits are NOT read by the economics — they are attribution.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as vec_map from './deps/sui/vec_map.js';
import * as credit from './deps/partyos/credit.js';
import * as recording_party_role from './recording_party_role.js';
import * as vec_set from './deps/sui/vec_set.js';
const $moduleName = '@local-pkg/recording_credits::recording_credits';
export const RecordingCreditsKey = new MoveTuple({ name: `${$moduleName}::RecordingCreditsKey`, fields: [bcs.bool()] });
export const RecordingCredits = new MoveStruct({ name: `${$moduleName}::RecordingCredits`, fields: {
        /** Map of party IDs to their credit (display name + roles). */
        credits: vec_map.VecMap(bcs.Address, credit.Credit(recording_party_role.RecordingPartyRole)),
        /** IDs of the primary artists. Always a subset of `credits`. */
        primary_artist_ids: vec_set.VecSet(bcs.Address),
        /** IDs of the featured artists. Always a subset of `credits`. */
        featured_artist_ids: vec_set.VecSet(bcs.Address)
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
        string,
        string
    ];
}
/**
 * Adds a credit for a party on the recording, lazily creating the credits record
 * on first use. Each credit must have 1-10 roles, and a party may hold at most one
 * credit. Requires the recording's admin capability.
 */
export function addCredit(options: AddCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "party", "credit"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
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
        string,
        string
    ];
}
/**
 * Removes a party's credit. Also drops them from the primary/featured sets,
 * preserving the invariant that those are subsets of the credited parties.
 * Requires the recording's admin capability.
 */
export function removeCredit(options: RemoveCreditOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'remove_credit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddPrimaryArtistArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
}
export interface AddPrimaryArtistOptions {
    package?: string;
    arguments: AddPrimaryArtistArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Designates an already-credited party as a primary artist. The party must be
 * credited and not already a primary or featured artist.
 */
export function addPrimaryArtist(options: AddPrimaryArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "party"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'add_primary_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemovePrimaryArtistArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface RemovePrimaryArtistOptions {
    package?: string;
    arguments: RemovePrimaryArtistArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Removes a party from the primary-artist set (leaves the credit intact). */
export function removePrimaryArtist(options: RemovePrimaryArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'remove_primary_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddFeaturedArtistArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    party: RawTransactionArgument<string>;
}
export interface AddFeaturedArtistOptions {
    package?: string;
    arguments: AddFeaturedArtistArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        party: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Designates an already-credited party as a featured artist. The party must be
 * credited and not already a primary or featured artist.
 */
export function addFeaturedArtist(options: AddFeaturedArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "party"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'add_featured_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveFeaturedArtistArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface RemoveFeaturedArtistOptions {
    package?: string;
    arguments: RemoveFeaturedArtistArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Removes a party from the featured-artist set (leaves the credit intact). */
export function removeFeaturedArtist(options: RemoveFeaturedArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'remove_featured_artist',
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
        string,
        string
    ];
}
/** Returns whether a credits record has been attached to this recording yet. */
export function hasCredits(options: HasCreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
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
        string,
        string
    ];
}
/** Returns the party-to-credit map. Aborts if no credits are attached. */
export function credits(options: CreditsOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'credits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface PrimaryArtistIdsArguments {
    self: RawTransactionArgument<string>;
}
export interface PrimaryArtistIdsOptions {
    package?: string;
    arguments: PrimaryArtistIdsArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the primary-artist IDs. Aborts if no credits are attached. */
export function primaryArtistIds(options: PrimaryArtistIdsOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'primary_artist_ids',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface FeaturedArtistIdsArguments {
    self: RawTransactionArgument<string>;
}
export interface FeaturedArtistIdsOptions {
    package?: string;
    arguments: FeaturedArtistIdsArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the featured-artist IDs. Aborts if no credits are attached. */
export function featuredArtistIds(options: FeaturedArtistIdsOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'featured_artist_ids',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsPrimaryArtistArguments {
    self: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface IsPrimaryArtistOptions {
    package?: string;
    arguments: IsPrimaryArtistArguments | [
        self: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns whether the party is a primary artist (false if no credits attached). */
export function isPrimaryArtist(options: IsPrimaryArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'is_primary_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsFeaturedArtistArguments {
    self: RawTransactionArgument<string>;
    partyId: RawTransactionArgument<string>;
}
export interface IsFeaturedArtistOptions {
    package?: string;
    arguments: IsFeaturedArtistArguments | [
        self: RawTransactionArgument<string>,
        partyId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns whether the party is a featured artist (false if no credits attached). */
export function isFeaturedArtist(options: IsFeaturedArtistOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null,
        '0x2::object::ID'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "partyId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_credits',
        function: 'is_featured_artist',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}