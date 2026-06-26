/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the roles that parties can hold on a composition. Compositions are the
 * underlying musical works (melody + lyrics), and these roles represent the
 * writing and adaptation contributions to them.
 * 
 * ### Design
 * 
 * `CompositionPartyRole` is a closed enum: variants can only be constructed and
 * matched inside this module, so the `new_*_role` constructors are the external
 * write-API and `name()` is the external read-API.
 * 
 * - **No seniority axis.** Unlike recording roles, composition roles carry no
 *   level — a writer either contributed in a given capacity or did not.
 * - **`Custom` is the escape hatch.** The canonical variants cover the common
 *   writing vocabulary; anything outside it is a `Custom(name)` whose name is
 *   validated. Prefer a canonical variant when one fits.
 * - **`name()` is the canonical identifier**, returned as a stable PascalCase
 *   token (e.g. `"Songwriter"`). For `Custom`, `name()` returns the user-supplied
 *   string.
 * 
 * These identifiers are Miso's own canonical vocabulary; any overlap with an
 * external standard (e.g. DDEX) is coincidental, not a reproduction of it.
 */

import { MoveEnum, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/composition_credits::composition_party_role';
/** Represents a party's role on a composition. */
export const CompositionPartyRole = new MoveEnum({ name: `${$moduleName}::CompositionPartyRole`, fields: {
        /** Adapted an existing work into this composition. */
        Adapter: null,
        /** Arranged the musical parts of the composition. */
        Arranger: null,
        /** Composed the music of the composition. */
        Composer: null,
        /** Wrote the lyrics of the composition. */
        Lyricist: null,
        /** Wrote both music and lyrics of the composition. */
        Songwriter: null,
        /** Translated the lyrics of the composition. */
        Translator: null,
        /**
         * A user-defined role not covered by a canonical variant. Carries the role name
         * (validated). An escape hatch — prefer a canonical variant when one fits.
         */
        Custom: bcs.string()
    } });
export interface NewAdapterRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Adapter role. */
export function newAdapterRole(options: NewAdapterRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_adapter_role',
    });
}
export interface NewArrangerRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Arranger role. */
export function newArrangerRole(options: NewArrangerRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_arranger_role',
    });
}
export interface NewComposerRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Composer role. */
export function newComposerRole(options: NewComposerRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_composer_role',
    });
}
export interface NewLyricistRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Lyricist role. */
export function newLyricistRole(options: NewLyricistRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_lyricist_role',
    });
}
export interface NewSongwriterRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Songwriter role. */
export function newSongwriterRole(options: NewSongwriterRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_songwriter_role',
    });
}
export interface NewTranslatorRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Translator role. */
export function newTranslatorRole(options: NewTranslatorRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_translator_role',
    });
}
export interface NewCustomRoleArguments {
    roleName: RawTransactionArgument<string>;
}
export interface NewCustomRoleOptions {
    package?: string;
    arguments: NewCustomRoleArguments | [
        roleName: RawTransactionArgument<string>
    ];
}
/**
 * Creates a new Custom role with a user-defined name. The name freezes into
 * credits, so it is validated here. Prefer a canonical variant when one fits.
 */
export function newCustomRole(options: NewCustomRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    const argumentsTypes = [
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["roleName"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'new_custom_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
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
/**
 * Returns the canonical identifier of the role as a stable PascalCase token. For
 * `Custom`, returns the user-supplied name.
 */
export function name(options: NameOptions) {
    const packageAddress = options.package ?? '@local-pkg/composition_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'composition_party_role',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}