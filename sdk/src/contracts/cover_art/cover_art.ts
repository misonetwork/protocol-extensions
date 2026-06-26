/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * The evolvable cover art value used by the recording/release cover art
 * extensions.
 * 
 * CoverArt format changes over time (static-only → +animated → future formats).
 * Keeping it in an extension rather than immutable core means a new format is a
 * republish of this small package (or a brand-new cover art standard), not of the
 * frozen protocol. `CoverArt` references external storage via `ori::WalrusData`.
 */

import { MoveStruct, normalizeMoveArguments } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
import * as walrus_data from './deps/ori/walrus_data.js';
const $moduleName = '@local-pkg/cover_art::cover_art';
export const CoverArt = new MoveStruct({ name: `${$moduleName}::CoverArt`, fields: {
        still: walrus_data.WalrusData,
        animated: bcs.option(walrus_data.WalrusData)
    } });
export interface NewArguments {
    still: TransactionArgument;
    animated: TransactionArgument;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        still: TransactionArgument,
        animated: TransactionArgument
    ];
}
/**
 * Creates cover art with a still image and optional animated version. Both
 * references must be Walrus blobs.
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["still", "animated"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface StillArguments {
    self: TransactionArgument;
}
export interface StillOptions {
    package?: string;
    arguments: StillArguments | [
        self: TransactionArgument
    ];
}
/** Returns a reference to the still image data. */
export function still(options: StillOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'still',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface AnimatedArguments {
    self: TransactionArgument;
}
export interface AnimatedOptions {
    package?: string;
    arguments: AnimatedArguments | [
        self: TransactionArgument
    ];
}
/** Returns a reference to the optional animated cover art data. */
export function animated(options: AnimatedOptions) {
    const packageAddress = options.package ?? '@local-pkg/cover_art';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'cover_art',
        function: 'animated',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}