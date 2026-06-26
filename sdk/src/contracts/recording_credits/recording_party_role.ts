/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the roles that parties can hold on a recording. Recordings are audio
 * performances of compositions, and these roles represent the various production
 * and performance contributions.
 * 
 * ### Design
 * 
 * `RecordingPartyRole` is a closed enum: variants can only be constructed and
 * matched inside this module, so the `new_*_role` constructors are the external
 * write-API and `name()` is the external read-API.
 * 
 * - **Seniority is a separate axis.** Most roles carry an optional
 *   `RecordingPartyRoleLevel` (Lead, Assistant, Additional, …). Industry variants
 *   like "Second Engineer" or "Additional Producer" are expressed as a base role
 *   plus a level, not as their own variants — this keeps the role set compact
 *   without losing the distinction.
 * - **`Custom` is the escape hatch.** The canonical variants cover the common
 *   vocabulary; anything outside it is a `Custom(name, level)` whose name is
 *   validated like an instrument name. Prefer a canonical variant when one fits.
 * - **`name()` is the canonical identifier**, returned as a stable PascalCase
 *   token (e.g. `"MixingEngineer"`). It doubles as an on-chain match key and as
 *   the seed for off-chain display/localization. For `Custom`, `name()` returns
 *   the user-supplied string; for `Instrumentalist`, it returns
 *   `"Instrumentalist"` (the instrument itself is read off-chain).
 * 
 * These identifiers are Miso's own canonical vocabulary; any overlap with an
 * external standard (e.g. DDEX) is coincidental, not a reproduction of it.
 */

import { MoveEnum, MoveTuple, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction, type TransactionArgument } from '@mysten/sui/transactions';
const $moduleName = '@local-pkg/recording_credits::recording_party_role';
/** Indicates the seniority or prominence level of a party. */
export const RecordingPartyRoleLevel = new MoveEnum({ name: `${$moduleName}::RecordingPartyRoleLevel`, fields: {
        /** Additional/supplementary party. */
        Additional: null,
        /** Assistant to the primary party. */
        Assistant: null,
        /** Associate-level party. */
        Associate: null,
        /** Backing/support role (e.g., backing vocals). */
        Backing: null,
        /** Executive-level oversight role. */
        Executive: null,
        /** Featured prominently on the recording. */
        Featured: null,
        /** Lead/primary party in this role. */
        Lead: null,
        /** Primary artist on the recording. */
        Primary: null,
        /** Principal party with primary responsibility. */
        Principal: null
    } });
/**
 * Represents a party's role on a recording. Most roles carry an optional level to
 * indicate seniority/prominence; `ArtistsAndRepertoire` and `Copyist` are
 * clerical/business roles that do not.
 */
export const RecordingPartyRole = new MoveEnum({ name: `${$moduleName}::RecordingPartyRole`, fields: {
        /** Performed voice acting or spoken-word performance. */
        Actor: bcs.option(RecordingPartyRoleLevel),
        /** Arranged the musical parts for the recording. */
        Arranger: bcs.option(RecordingPartyRoleLevel),
        /** A&R representative who discovered or developed the artist. */
        ArtistsAndRepertoire: null,
        /** Led the band or backing ensemble. */
        BandLeader: bcs.option(RecordingPartyRoleLevel),
        /** Performed as part of a choir. */
        Choir: bcs.option(RecordingPartyRoleLevel),
        /** Directed the choir performance. */
        ChoirMaster: bcs.option(RecordingPartyRoleLevel),
        /** Lead performer of an orchestra/ensemble (e.g. first-chair). */
        ConcertMaster: bcs.option(RecordingPartyRoleLevel),
        /** Conducted the orchestra or ensemble. */
        Conductor: bcs.option(RecordingPartyRoleLevel),
        /** Hired and managed session musicians. */
        Contractor: bcs.option(RecordingPartyRoleLevel),
        /** Prepared written music parts for performers. */
        Copyist: null,
        /** Performed/assembled the recording as a disc jockey. */
        DJ: bcs.option(RecordingPartyRoleLevel),
        /** Edited and compiled audio takes. */
        Editor: bcs.option(RecordingPartyRoleLevel),
        /** General engineering contribution not covered by a specific engineer role. */
        Engineer: bcs.option(RecordingPartyRoleLevel),
        /** Performed as part of a musical ensemble. */
        Ensemble: bcs.option(RecordingPartyRoleLevel),
        /** Played an instrument on the recording. Carries the instrument name. */
        Instrumentalist: new MoveTuple({ name: `RecordingPartyRole.Instrumentalist`, fields: [bcs.string(), bcs.option(RecordingPartyRoleLevel)] }),
        /** Mastered the final audio for distribution. */
        MasteringEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Mixed the multitrack recording into stereo/surround. */
        MixingEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Directed the musical performance. */
        MusicDirector: bcs.option(RecordingPartyRoleLevel),
        /** Oversaw music selection and licensing. */
        MusicSupervisor: bcs.option(RecordingPartyRoleLevel),
        /** Narrated spoken content. */
        Narrator: bcs.option(RecordingPartyRoleLevel),
        /** Performed as part of an orchestra. */
        Orchestra: bcs.option(RecordingPartyRoleLevel),
        /** Created orchestral arrangements. */
        Orchestrator: bcs.option(RecordingPartyRoleLevel),
        /** Performed on the recording (general performer). */
        Performer: bcs.option(RecordingPartyRoleLevel),
        /** Oversaw the creative and technical aspects of the recording. */
        Producer: bcs.option(RecordingPartyRoleLevel),
        /** Programmed beats, synths, or electronic elements. */
        Programmer: bcs.option(RecordingPartyRoleLevel),
        /** Operated recording equipment during sessions. */
        RecordingEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Created a remix of the recording. */
        RemixingEngineer: bcs.option(RecordingPartyRoleLevel),
        /** Performed a solo part. */
        Soloist: bcs.option(RecordingPartyRoleLevel),
        /** Created sound effects or sonic textures. */
        SoundDesigner: bcs.option(RecordingPartyRoleLevel),
        /** Delivered spoken-word or presentation content. */
        Speaker: bcs.option(RecordingPartyRoleLevel),
        /** Provided vocals on the recording. */
        Vocalist: bcs.option(RecordingPartyRoleLevel),
        /**
         * A user-defined role not covered by a canonical variant. Carries the role name
         * (validated like an instrument name) and an optional level. An escape hatch —
         * prefer a canonical variant when one fits.
         */
        Custom: new MoveTuple({ name: `RecordingPartyRole.Custom`, fields: [bcs.string(), bcs.option(RecordingPartyRoleLevel)] })
    } });
export interface NewActorRoleArguments {
    level: TransactionArgument;
}
export interface NewActorRoleOptions {
    package?: string;
    arguments: NewActorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Actor role with optional level. */
export function newActorRole(options: NewActorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_actor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewArrangerRoleArguments {
    level: TransactionArgument;
}
export interface NewArrangerRoleOptions {
    package?: string;
    arguments: NewArrangerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Arranger role with optional level. */
export function newArrangerRole(options: NewArrangerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_arranger_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewArtistsAndRepertoireRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Artists & Repertoire role. */
export function newArtistsAndRepertoireRole(options: NewArtistsAndRepertoireRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_artists_and_repertoire_role',
    });
}
export interface NewBandLeaderRoleArguments {
    level: TransactionArgument;
}
export interface NewBandLeaderRoleOptions {
    package?: string;
    arguments: NewBandLeaderRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Band Leader role with optional level. */
export function newBandLeaderRole(options: NewBandLeaderRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_band_leader_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewChoirRoleArguments {
    level: TransactionArgument;
}
export interface NewChoirRoleOptions {
    package?: string;
    arguments: NewChoirRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Choir role with optional level. */
export function newChoirRole(options: NewChoirRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_choir_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewChoirMasterRoleArguments {
    level: TransactionArgument;
}
export interface NewChoirMasterRoleOptions {
    package?: string;
    arguments: NewChoirMasterRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Choir Master role with optional level. */
export function newChoirMasterRole(options: NewChoirMasterRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_choir_master_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewConcertMasterRoleArguments {
    level: TransactionArgument;
}
export interface NewConcertMasterRoleOptions {
    package?: string;
    arguments: NewConcertMasterRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Concert Master role with optional level. */
export function newConcertMasterRole(options: NewConcertMasterRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_concert_master_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewConductorRoleArguments {
    level: TransactionArgument;
}
export interface NewConductorRoleOptions {
    package?: string;
    arguments: NewConductorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Conductor role with optional level. */
export function newConductorRole(options: NewConductorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_conductor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewContractorRoleArguments {
    level: TransactionArgument;
}
export interface NewContractorRoleOptions {
    package?: string;
    arguments: NewContractorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Contractor role with optional level. */
export function newContractorRole(options: NewContractorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_contractor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewCopyistRoleOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a new Copyist role. */
export function newCopyistRole(options: NewCopyistRoleOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_copyist_role',
    });
}
export interface NewDjRoleArguments {
    level: TransactionArgument;
}
export interface NewDjRoleOptions {
    package?: string;
    arguments: NewDjRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new DJ role with optional level. */
export function newDjRole(options: NewDjRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_dj_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewEditorRoleArguments {
    level: TransactionArgument;
}
export interface NewEditorRoleOptions {
    package?: string;
    arguments: NewEditorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Editor role with optional level. */
export function newEditorRole(options: NewEditorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_editor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewEngineerRoleOptions {
    package?: string;
    arguments: NewEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new (general) Engineer role with optional level. */
export function newEngineerRole(options: NewEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewEnsembleRoleArguments {
    level: TransactionArgument;
}
export interface NewEnsembleRoleOptions {
    package?: string;
    arguments: NewEnsembleRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Ensemble role with optional level. */
export function newEnsembleRole(options: NewEnsembleRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_ensemble_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewInstrumentalistRoleArguments {
    instrument: RawTransactionArgument<string>;
    level: TransactionArgument;
}
export interface NewInstrumentalistRoleOptions {
    package?: string;
    arguments: NewInstrumentalistRoleArguments | [
        instrument: RawTransactionArgument<string>,
        level: TransactionArgument
    ];
}
/**
 * Creates a new Instrumentalist role with instrument name and optional level. The
 * instrument name freezes into credits, so it is validated here.
 */
export function newInstrumentalistRole(options: NewInstrumentalistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["instrument", "level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_instrumentalist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMasteringEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewMasteringEngineerRoleOptions {
    package?: string;
    arguments: NewMasteringEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Mastering Engineer role with optional level. */
export function newMasteringEngineerRole(options: NewMasteringEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_mastering_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMixingEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewMixingEngineerRoleOptions {
    package?: string;
    arguments: NewMixingEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Mixing Engineer role with optional level. */
export function newMixingEngineerRole(options: NewMixingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_mixing_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMusicDirectorRoleArguments {
    level: TransactionArgument;
}
export interface NewMusicDirectorRoleOptions {
    package?: string;
    arguments: NewMusicDirectorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Music Director role with optional level. */
export function newMusicDirectorRole(options: NewMusicDirectorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_music_director_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewMusicSupervisorRoleArguments {
    level: TransactionArgument;
}
export interface NewMusicSupervisorRoleOptions {
    package?: string;
    arguments: NewMusicSupervisorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Music Supervisor role with optional level. */
export function newMusicSupervisorRole(options: NewMusicSupervisorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_music_supervisor_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewNarratorRoleArguments {
    level: TransactionArgument;
}
export interface NewNarratorRoleOptions {
    package?: string;
    arguments: NewNarratorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Narrator role with optional level. */
export function newNarratorRole(options: NewNarratorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_narrator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewOrchestraRoleArguments {
    level: TransactionArgument;
}
export interface NewOrchestraRoleOptions {
    package?: string;
    arguments: NewOrchestraRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Orchestra role with optional level. */
export function newOrchestraRole(options: NewOrchestraRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_orchestra_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewOrchestratorRoleArguments {
    level: TransactionArgument;
}
export interface NewOrchestratorRoleOptions {
    package?: string;
    arguments: NewOrchestratorRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Orchestrator role with optional level. */
export function newOrchestratorRole(options: NewOrchestratorRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_orchestrator_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewPerformerRoleArguments {
    level: TransactionArgument;
}
export interface NewPerformerRoleOptions {
    package?: string;
    arguments: NewPerformerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Performer role with optional level. */
export function newPerformerRole(options: NewPerformerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_performer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewProducerRoleArguments {
    level: TransactionArgument;
}
export interface NewProducerRoleOptions {
    package?: string;
    arguments: NewProducerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Producer role with optional level. */
export function newProducerRole(options: NewProducerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_producer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewProgrammerRoleArguments {
    level: TransactionArgument;
}
export interface NewProgrammerRoleOptions {
    package?: string;
    arguments: NewProgrammerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Programmer role with optional level. */
export function newProgrammerRole(options: NewProgrammerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_programmer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewRecordingEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewRecordingEngineerRoleOptions {
    package?: string;
    arguments: NewRecordingEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Recording Engineer role with optional level. */
export function newRecordingEngineerRole(options: NewRecordingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_recording_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewRemixingEngineerRoleArguments {
    level: TransactionArgument;
}
export interface NewRemixingEngineerRoleOptions {
    package?: string;
    arguments: NewRemixingEngineerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Remixing Engineer role with optional level. */
export function newRemixingEngineerRole(options: NewRemixingEngineerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_remixing_engineer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewSoloistRoleArguments {
    level: TransactionArgument;
}
export interface NewSoloistRoleOptions {
    package?: string;
    arguments: NewSoloistRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Soloist role with optional level. */
export function newSoloistRole(options: NewSoloistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_soloist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewSoundDesignerRoleArguments {
    level: TransactionArgument;
}
export interface NewSoundDesignerRoleOptions {
    package?: string;
    arguments: NewSoundDesignerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Sound Designer role with optional level. */
export function newSoundDesignerRole(options: NewSoundDesignerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_sound_designer_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewSpeakerRoleArguments {
    level: TransactionArgument;
}
export interface NewSpeakerRoleOptions {
    package?: string;
    arguments: NewSpeakerRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Speaker role with optional level. */
export function newSpeakerRole(options: NewSpeakerRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_speaker_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewVocalistRoleArguments {
    level: TransactionArgument;
}
export interface NewVocalistRoleOptions {
    package?: string;
    arguments: NewVocalistRoleArguments | [
        level: TransactionArgument
    ];
}
/** Creates a new Vocalist role with optional level. */
export function newVocalistRole(options: NewVocalistRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_vocalist_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewCustomRoleArguments {
    roleName: RawTransactionArgument<string>;
    level: TransactionArgument;
}
export interface NewCustomRoleOptions {
    package?: string;
    arguments: NewCustomRoleArguments | [
        roleName: RawTransactionArgument<string>,
        level: TransactionArgument
    ];
}
/**
 * Creates a new Custom role with a user-defined name and optional level. The name
 * freezes into credits, so it is validated like an instrument name. Prefer a
 * canonical variant when one fits.
 */
export function newCustomRole(options: NewCustomRoleOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["roleName", "level"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_custom_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NewAdditionalRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Additional level. */
export function newAdditionalRoleLevel(options: NewAdditionalRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_additional_role_level',
    });
}
export interface NewAssistantRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Assistant level. */
export function newAssistantRoleLevel(options: NewAssistantRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_assistant_role_level',
    });
}
export interface NewAssociateRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Associate level. */
export function newAssociateRoleLevel(options: NewAssociateRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_associate_role_level',
    });
}
export interface NewBackingRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Backing level. */
export function newBackingRoleLevel(options: NewBackingRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_backing_role_level',
    });
}
export interface NewExecutiveRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates an Executive level. */
export function newExecutiveRoleLevel(options: NewExecutiveRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_executive_role_level',
    });
}
export interface NewFeaturedRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Featured level. */
export function newFeaturedRoleLevel(options: NewFeaturedRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_featured_role_level',
    });
}
export interface NewLeadRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Lead level. */
export function newLeadRoleLevel(options: NewLeadRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_lead_role_level',
    });
}
export interface NewPrimaryRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Primary level. */
export function newPrimaryRoleLevel(options: NewPrimaryRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_primary_role_level',
    });
}
export interface NewPrincipalRoleLevelOptions {
    package?: string;
    arguments?: [
    ];
}
/** Creates a Principal level. */
export function newPrincipalRoleLevel(options: NewPrincipalRoleLevelOptions = {}) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'new_principal_role_level',
    });
}
export interface LevelArguments {
    self: TransactionArgument;
}
export interface LevelOptions {
    package?: string;
    arguments: LevelArguments | [
        self: TransactionArgument
    ];
}
/** Returns the optional level associated with this role. */
export function level(options: LevelOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'level',
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
 * `Custom`, returns the user-supplied name; for `Instrumentalist`, returns
 * `"Instrumentalist"` (the instrument is read off-chain).
 */
export function name(options: NameOptions) {
    const packageAddress = options.package ?? '@local-pkg/recording_credits';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'recording_party_role',
        function: 'name',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}