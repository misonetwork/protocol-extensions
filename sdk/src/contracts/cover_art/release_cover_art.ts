/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Release cover art, mapped to the release's disc structure: a release-level cover
 * plus optional per-disc cover art keyed by disc index. Stored as a dynamic field
 * on the release's UID, set/cleared via the release's cap-gated `uid_mut`.
 * 
 * Disc indices are validated against the release's actual disc count, so disc
 * cover art can only target a disc that exists. Discs are fixed at release
 * creation, so an index that is valid stays valid.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as cover_art from './cover_art.js';
import * as vec_map from './deps/sui/vec_map.js';
const $moduleName = '@local-pkg/cover_art::release_cover_art';
export const CoverArtKey = new MoveTuple({ name: `${$moduleName}::CoverArtKey`, fields: [bcs.bool()] });
export const ReleaseCoverArt = new MoveStruct({ name: `${$moduleName}::ReleaseCoverArt`, fields: {
        cover: bcs.option(cover_art.CoverArt),
        disc_cover_art: vec_map.VecMap(bcs.u64(), cover_art.CoverArt)
    } });
export interface SetCoverArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    art: TransactionArgument;
}
export interface SetCoverOptions {
    package?: string;
    arguments: SetCoverArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        art: TransactionArgument
    ];
}
/** Sets (or replaces) the release-level cover. */
export function setCover(options: SetCoverOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "art"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'set_cover',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UnsetCoverArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
}
export interface UnsetCoverOptions {
    package?: string;
    arguments: UnsetCoverArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>
    ];
}
/** Removes the release-level cover, if any. */
export function unsetCover(options: UnsetCoverOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'unset_cover',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SetDiscCoverArtArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    discIndex: RawTransactionArgument<number | bigint>;
    art: TransactionArgument;
}
export interface SetDiscCoverArtOptions {
    package?: string;
    arguments: SetDiscCoverArtArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        discIndex: RawTransactionArgument<number | bigint>,
        art: TransactionArgument
    ];
}
/**
 * Sets (or replaces) the cover art for a specific disc. The disc index must be
 * within the release's disc count.
 */
export function setDiscCoverArt(options: SetDiscCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "discIndex", "art"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'set_disc_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UnsetDiscCoverArtArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    discIndex: RawTransactionArgument<number | bigint>;
}
export interface UnsetDiscCoverArtOptions {
    package?: string;
    arguments: UnsetDiscCoverArtArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        discIndex: RawTransactionArgument<number | bigint>
    ];
}
/** Removes the cover art for a specific disc, if any. */
export function unsetDiscCoverArt(options: UnsetDiscCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "discIndex"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'unset_disc_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface HasCoverArtArguments {
    self: RawTransactionArgument<string>;
}
export interface HasCoverArtOptions {
    package?: string;
    arguments: HasCoverArtArguments | [
        self: RawTransactionArgument<string>
    ];
}
/** Returns whether a cover art record is attached to this release. */
export function hasCoverArt(options: HasCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'has_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface CoverArguments {
    self: RawTransactionArgument<string>;
}
export interface CoverOptions {
    package?: string;
    arguments: CoverArguments | [
        self: RawTransactionArgument<string>
    ];
}
/**
 * Returns the release-level cover (none if unset). Aborts if no cover art record
 * is attached at all.
 */
export function cover(options: CoverOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'cover',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface HasDiscCoverArtArguments {
    self: RawTransactionArgument<string>;
    discIndex: RawTransactionArgument<number | bigint>;
}
export interface HasDiscCoverArtOptions {
    package?: string;
    arguments: HasDiscCoverArtArguments | [
        self: RawTransactionArgument<string>,
        discIndex: RawTransactionArgument<number | bigint>
    ];
}
/** Returns whether the given disc has cover art. */
export function hasDiscCoverArt(options: HasDiscCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "discIndex"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'has_disc_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface DiscCoverArtArguments {
    self: RawTransactionArgument<string>;
    discIndex: RawTransactionArgument<number | bigint>;
}
export interface DiscCoverArtOptions {
    package?: string;
    arguments: DiscCoverArtArguments | [
        self: RawTransactionArgument<string>,
        discIndex: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Returns the cover art for a specific disc (by value — `CoverArt` is `copy`).
 * Aborts if none is attached.
 */
export function discCoverArt(options: DiscCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "discIndex"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'release_cover_art',
        function: 'disc_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}