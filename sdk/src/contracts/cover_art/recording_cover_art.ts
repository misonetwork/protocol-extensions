/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Recording cover art: a single `CoverArt` attached as a dynamic field on the
 * recording's UID, set/cleared via the recording's cap-gated `uid_mut`.
 */

import { MoveTuple, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/cover_art::recording_cover_art';
export const CoverArtKey = new MoveTuple({ name: `${$moduleName}::CoverArtKey`, fields: [bcs.bool()] });
export interface SetArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
    art: TransactionArgument;
}
export interface SetOptions {
    package?: string;
    arguments: SetArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>,
        art: TransactionArgument
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Sets (or replaces) the recording's cover art. */
export function set(options: SetOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap", "art"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_cover_art',
        function: 'set',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UnsetArguments {
    self: RawTransactionArgument<string>;
    cap: RawTransactionArgument<string>;
}
export interface UnsetOptions {
    package?: string;
    arguments: UnsetArguments | [
        self: RawTransactionArgument<string>,
        cap: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Removes the recording's cover art, if any. */
export function unset(options: UnsetOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "cap"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_cover_art',
        function: 'unset',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
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
    typeArguments: [
        string,
        string
    ];
}
/** Returns whether the recording has cover art attached. */
export function hasCoverArt(options: HasCoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_cover_art',
        function: 'has_cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface CoverArtArguments {
    self: RawTransactionArgument<string>;
}
export interface CoverArtOptions {
    package?: string;
    arguments: CoverArtArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Returns the recording's cover art. Aborts if none is attached. */
export function coverArt(options: CoverArtOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_cover_art',
        function: 'cover_art',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}