/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Genre extension for Miso.
 * 
 * Genre is a classification, not protocol-verifiable state, so it lives in an
 * extension rather than the core `Recording`. This package owns two halves:
 * 
 * 1.  A **curated vocabulary** — `Genre` objects created by a `GenreRegistryCap`
 *     holder (Miso), derived by canonical name so the vocabulary stays
 *     deduplicated and canonical (no "hip-hop" vs "Hip Hop" forks).
 * 2.  **Self-classification** — a recording's admin selects a primary genre and
 *     optional secondary genres (the model artists know from DSP uploads). The
 *     selection attaches to the recording via its `&mut UID` (the sanctioned
 *     extension escape hatch), gated by the `RecordingAdminCap`.
 * 
 * A curated/attributed assignment layer (e.g. Miso editorial, for genre-based
 * rewards) can be added later as a coexisting source without changing the `Genre`
 * objects or this self-assignment path.
 */

import { MoveStruct, MoveTuple, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/genre::genre';
export const GENRE = new MoveStruct({ name: `${$moduleName}::GENRE`, fields: {
        dummy_field: bcs.bool()
    } });
export const GenreRegistry = new MoveStruct({ name: `${$moduleName}::GenreRegistry`, fields: {
        id: bcs.Address
    } });
export const GenreRegistryCap = new MoveStruct({ name: `${$moduleName}::GenreRegistryCap`, fields: {
        id: bcs.Address
    } });
export const Genre = new MoveStruct({ name: `${$moduleName}::Genre`, fields: {
        id: bcs.Address,
        /** Canonical genre name (e.g. "HIP_HOP"). */
        name: bcs.string()
    } });
export const GenreKey = new MoveTuple({ name: `${$moduleName}::GenreKey`, fields: [bcs.string()] });
export const GenreAssignmentKey = new MoveTuple({ name: `${$moduleName}::GenreAssignmentKey`, fields: [bcs.bool()] });
export const GenreAssignment = new MoveStruct({ name: `${$moduleName}::GenreAssignment`, fields: {
        primary: bcs.Address,
        /**
         * Epoch the primary genre was last set. The primary cannot change again until
         * `MIN_PRIMARY_GENRE_EPOCHS` later (anti-churn for reward integrity).
         */
        primary_set_epoch: bcs.u64(),
        secondary: bcs.vector(bcs.Address)
    } });
export const GenreCreatedEvent = new MoveStruct({ name: `${$moduleName}::GenreCreatedEvent`, fields: {
        genre_id: bcs.Address,
        name: bcs.string()
    } });
export const PrimaryGenreSetEvent = new MoveStruct({ name: `${$moduleName}::PrimaryGenreSetEvent`, fields: {
        recording_id: bcs.Address,
        genre_id: bcs.Address,
        /**
         * Epoch this was set; the primary is locked until
         * `set_epoch + MIN_PRIMARY_GENRE_EPOCHS`.
         */
        set_epoch: bcs.u64()
    } });
export const SecondaryGenreAddedEvent = new MoveStruct({ name: `${$moduleName}::SecondaryGenreAddedEvent`, fields: {
        recording_id: bcs.Address,
        genre_id: bcs.Address
    } });
export const SecondaryGenreRemovedEvent = new MoveStruct({ name: `${$moduleName}::SecondaryGenreRemovedEvent`, fields: {
        recording_id: bcs.Address,
        genre_id: bcs.Address
    } });
export interface NewArguments {
    _: RawTransactionArgument<string>;
    registry: RawTransactionArgument<string>;
    name: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        _: RawTransactionArgument<string>,
        registry: RawTransactionArgument<string>,
        name: RawTransactionArgument<string>
    ];
}
/**
 * Creates a new genre in the canonical vocabulary. Cap-gated: only the registry
 * curator can extend the vocabulary. Derived by canonical name, so creating the
 * same name twice aborts (dedup is automatic). The `Genre` is frozen — immutable
 * and globally readable by reference.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["_", "registry", "name"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DeriveGenreIdArguments {
    self: RawTransactionArgument<string>;
    name: RawTransactionArgument<string>;
}
export interface DeriveGenreIdOptions {
    package?: string;
    arguments: DeriveGenreIdArguments | [
        self: RawTransactionArgument<string>,
        name: RawTransactionArgument<string>
    ];
}
/**
 * Derives the object id a `Genre` with the given name would have, without creating
 * it. Lets clients resolve/check a genre id offline.
 */
export function deriveGenreId(options: DeriveGenreIdOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "name"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'derive_genre_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SetPrimaryGenreArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    genre: RawTransactionArgument<string>;
}
export interface SetPrimaryGenreOptions {
    package?: string;
    arguments: SetPrimaryGenreArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        genre: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Sets (or replaces) the recording's primary genre. Gated by the recording's admin
 * capability — self-classification by the rightsholder.
 *
 * The first set is free; changing an existing primary requires at least
 * `MIN_PRIMARY_GENRE_EPOCHS` to have passed since it was last set.
 */
export function setPrimaryGenre(options: SetPrimaryGenreOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "genre"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'set_primary_genre',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddSecondaryGenreArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    genre: RawTransactionArgument<string>;
}
export interface AddSecondaryGenreOptions {
    package?: string;
    arguments: AddSecondaryGenreArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        genre: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Adds a secondary genre to the recording. Requires a primary genre first. Rejects
 * duplicates and a secondary equal to the primary.
 */
export function addSecondaryGenre(options: AddSecondaryGenreOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "genre"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'add_secondary_genre',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveSecondaryGenreArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    genre: RawTransactionArgument<string>;
}
export interface RemoveSecondaryGenreOptions {
    package?: string;
    arguments: RemoveSecondaryGenreArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        genre: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Removes a secondary genre from the recording. */
export function removeSecondaryGenre(options: RemoveSecondaryGenreOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "genre"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'remove_secondary_genre',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IdArguments {
    self: RawTransactionArgument<string>;
}
export interface IdOptions {
    package?: string;
    arguments: IdArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the genre's object id. */
export function id(options: IdOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NameArguments {
    self: RawTransactionArgument<string>;
}
export interface NameOptions {
    package?: string;
    arguments: NameArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns the genre's canonical name. */
export function name(options: NameOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface HasGenreArguments {
    self: RawTransactionArgument<string>;
}
export interface HasGenreOptions {
    package?: string;
    arguments: HasGenreArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns whether the recording has a genre assignment. */
export function hasGenre(options: HasGenreOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'has_genre',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface PrimaryGenreArguments {
    self: RawTransactionArgument<string>;
}
export interface PrimaryGenreOptions {
    package?: string;
    arguments: PrimaryGenreArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the recording's primary genre id, if set. */
export function primaryGenre(options: PrimaryGenreOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'primary_genre',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SecondaryGenresArguments {
    self: RawTransactionArgument<string>;
}
export interface SecondaryGenresOptions {
    package?: string;
    arguments: SecondaryGenresArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the recording's secondary genre ids (empty if none). */
export function secondaryGenres(options: SecondaryGenresOptions) {
    const packageAddress = options.package ?? '@local-pkg/genre';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'genre',
        function: 'secondary_genres',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}