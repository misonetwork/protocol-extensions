// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Public facade for the Miso first-party credits extensions (recording,
// composition, release). Re-exports the codegen'd, type-safe Move-call builders
// grouped by work type, plus the role constructors for each work. Adds a handful
// of hand-written helpers that the codegen layer can't express: building the
// partyos `Credit<Role>` argument, creating a `Party`, and reading + BCS-parsing
// the credits dynamic field off a work.
//
// Builders follow the Sui SDK thunk pattern: each returns a `(tx: Transaction) => …`
// thunk that adds commands to a caller-owned `Transaction`, so flows compose.

import type { ClientWithCoreApi } from "@mysten/sui/client";
import {
  type Transaction,
  type TransactionObjectArgument,
} from "@mysten/sui/transactions";

import * as recordingCredits from "../contracts/recording_credits/recording_credits.js";
import * as recordingRole from "../contracts/recording_credits/recording_party_role.js";
import * as compositionCredits from "../contracts/composition_credits/composition_credits.js";
import * as compositionRole from "../contracts/composition_credits/composition_party_role.js";
import * as releaseCredits from "../contracts/release_credits/release_credits.js";
import * as releaseRole from "../contracts/release_credits/release_party_role.js";

// ============================================================================
// Tx-call builders, grouped by work type
// ============================================================================

/**
 * Recording credits write/read Move-call builders. Callers reach the generated,
 * type-safe builders as `credits.recording.addCredit(...)`, etc.
 *
 * `addCredit`/`removeCredit`/`add*Artist`/etc. all take the recording's two
 * phantom share types as `typeArguments: [RecordingShare, CompositionShare]`.
 */
export const recording = recordingCredits;

/**
 * Composition credits write/read Move-call builders. Reached as
 * `credits.composition.addCredit(...)`, etc. These take the composition's single
 * phantom share type as `typeArguments: [CompositionShare]`.
 */
export const composition = compositionCredits;

/**
 * Release credits write/read Move-call builders. Reached as
 * `credits.release.addCredit(...)`, etc. Releases are not generic, so these take
 * no type arguments.
 */
export const release = releaseCredits;

// ============================================================================
// Role constructors, grouped by work type
// ============================================================================

/**
 * Recording party-role + role-level constructors (`recordingRoles.newVocalistRole`,
 * `recordingRoles.newProducerRole`, …, `recordingRoles.newCustomRole`, plus the
 * `new*RoleLevel` constructors, `name`, and `level`). Each returns a thunk that
 * yields a `RecordingPartyRole` argument for `buildCredit`.
 */
export const recordingRoles = recordingRole;

/**
 * Composition party-role constructors (`compositionRoles.newComposerRole`, …,
 * `compositionRoles.newCustomRole`, plus `name`). Each returns a thunk that yields
 * a `CompositionPartyRole` argument for `buildCredit`.
 */
export const compositionRoles = compositionRole;

/**
 * Release party-role constructors (`releaseRoles.newPrimaryRole`,
 * `releaseRoles.newFeaturedRole`, plus `name`). Each returns a thunk that yields a
 * `ReleasePartyRole` argument for `buildCredit`.
 */
export const releaseRoles = releaseRole;

// ============================================================================
// Credit helper (partyos::credit)
// ============================================================================

/** Whether a party is an individual person or a group of parties. */
export type PartyKind = "Individual" | "Group";

export interface BuildCreditParams {
  /** PartyOS package id (the `partyos::credit` module home). */
  partyOsPackageId: string;
  /**
   * Fully-qualified role type this credit's roles are, e.g.
   * `${recordingCreditsPkg}::recording_party_role::RecordingPartyRole`. Used as
   * the `Credit<Role>` type argument and the element type of the role vector.
   */
  roleType: string;
  /** Human-readable display name for the credit (1-200 bytes, non-empty). */
  displayName: string;
  /**
   * Role arguments (the outputs of the matching `*Roles.new*Role(...)` thunks,
   * each added to the tx). 1-N roles; the work module enforces its own cap.
   */
  roles: TransactionObjectArgument[];
}

/**
 * Builds a partyos `Credit<Role>` argument via `credit::new(display_name, roles)`,
 * ready to pass as the `credit` argument of any work's `addCredit`. Wraps the raw
 * `moveCall` because `partyos::credit` is an external package and is not part of
 * this SDK's codegen surface.
 */
export function buildCredit(params: BuildCreditParams) {
  const { partyOsPackageId, roleType, displayName, roles } = params;
  return (tx: Transaction): TransactionObjectArgument =>
    tx.moveCall({
      target: `${partyOsPackageId}::credit::new`,
      typeArguments: [roleType],
      arguments: [
        tx.pure.string(displayName),
        tx.makeMoveVec({ type: roleType, elements: roles }),
      ],
    });
}

// ============================================================================
// Party helper (partyos::party)
// ============================================================================

export interface CreatePartyParams {
  /** Individual person or a group of (individual) parties. */
  kind: PartyKind;
  /** Human-readable party name (1-200 bytes, non-empty). */
  name: string;
  /**
   * For `Group` parties, the object ids of the individual member parties to add.
   * Each must be an existing individual `Party` (added via the group's admin cap).
   * Ignored for `Individual` parties.
   */
  memberIds?: string[];
  /** Address that receives the new party's `PartyAdminCap`. */
  adminAddress: string;
  /** PartyOS package id (the `partyos::party` module home). */
  partyOsPackageId: string;
}

/**
 * Creates, populates (for groups), and shares a partyos `Party`, transferring its
 * `PartyAdminCap` to `adminAddress`. A thunk over raw `moveCall`s into
 * `party::new_*_kind` / `party::new` / `party::add_party` / `party::share`, since
 * `partyos::party` is external to this SDK's codegen surface.
 */
export function createParty(params: CreatePartyParams) {
  const { kind, name, memberIds, adminAddress, partyOsPackageId } = params;
  return (tx: Transaction): void => {
    const partyKind = tx.moveCall({
      target: `${partyOsPackageId}::party::new_${kind.toLowerCase()}_kind`,
    });
    const [party, partyAdminCap] = tx.moveCall({
      target: `${partyOsPackageId}::party::new`,
      arguments: [partyKind, tx.pure.string(name)],
    });
    if (kind === "Group" && memberIds?.length) {
      for (const memberId of memberIds) {
        tx.moveCall({
          target: `${partyOsPackageId}::party::add_party`,
          arguments: [party!, partyAdminCap!, tx.object(memberId)],
        });
      }
    }
    tx.moveCall({
      target: `${partyOsPackageId}::party::share`,
      arguments: [party!, partyAdminCap!],
    });
    tx.transferObjects([partyAdminCap!], tx.pure.address(adminAddress));
  };
}

// ============================================================================
// Parsed credit record types
// ============================================================================

/**
 * A parsed credit on a work: a display name plus that party's roles. The `roles`
 * are the raw BCS-parsed role enum values (`{ $kind, [Variant]: payload }`); use
 * the on-chain `name()` read or off-chain mapping to render them.
 */
export interface Credit {
  /** Party object id (hex address) the credit is attributed to. */
  partyId: string;
  /** Human-readable display name for the credit. */
  displayName: string;
  /** BCS-parsed role enum values (shape depends on the work's role type). */
  roles: unknown[];
}

/** Parsed recording credits: party credits plus primary/featured artist sets. */
export interface RecordingCredits {
  credits: Credit[];
  /** Party ids designated as primary artists (a subset of `credits`). */
  primaryArtistIds: string[];
  /** Party ids designated as featured artists (a subset of `credits`). */
  featuredArtistIds: string[];
}

/** Parsed composition credits: the party-to-credit map. */
export interface CompositionCredits {
  credits: Credit[];
}

/** Parsed release credits: the party-to-credit map (one role per credit). */
export interface ReleaseCredits {
  credits: Credit[];
}

// ============================================================================
// Read helpers — fetch + BCS-parse the credits dynamic field
// ============================================================================

/**
 * Each work's credits record lives under a `<Work>CreditsKey` unit-struct key on
 * the work's UID. Each key is a single-field tuple struct `(bool)` defaulting to
 * `false`, so its BCS serialization is a single `0x00` byte — the canonical
 * unit-struct key. The key BCS is identical across works; only the on-chain type
 * string differs (per module + struct name).
 */
const RECORDING_CREDITS_KEY_BCS = recordingCredits.RecordingCreditsKey.serialize([false]).toBytes();
const COMPOSITION_CREDITS_KEY_BCS = compositionCredits.CompositionCreditsKey.serialize([false]).toBytes();
const RELEASE_CREDITS_KEY_BCS = releaseCredits.ReleaseCreditsKey.serialize([false]).toBytes();

/** Fetches the raw BCS bytes of a work's credits dynamic field value, or null if absent. */
async function getCreditsFieldBytes(
  client: ClientWithCoreApi,
  workId: string,
  keyType: string,
  keyBcs: Uint8Array,
): Promise<Uint8Array | null> {
  try {
    const { dynamicField } = await client.core.getDynamicField({
      parentId: workId,
      name: { type: keyType, bcs: keyBcs },
    });
    return dynamicField.value.bcs ?? null;
  } catch {
    return null; // not-found (or unreadable) → no credits attached
  }
}

/** A single BCS-parsed `Credit` entry (`{ key: address, value: { display_name, roles } }`). */
type ParsedCreditEntry = {
  key: string;
  value: { display_name: string; roles: unknown[] };
};

function mapCreditEntries(entries: ParsedCreditEntry[]): Credit[] {
  return entries.map((e) => ({
    partyId: e.key,
    displayName: e.value.display_name,
    roles: e.value.roles,
  }));
}

/**
 * Fetches and parses a recording's credits. Returns `null` if no credits record
 * is attached. The work id is the `Recording` object id.
 */
export async function getRecordingCredits(
  client: ClientWithCoreApi,
  recordingId: string,
  recordingCreditsPackageId: string,
): Promise<RecordingCredits | null> {
  const bytes = await getCreditsFieldBytes(
    client,
    recordingId,
    `${recordingCreditsPackageId}::recording_credits::RecordingCreditsKey`,
    RECORDING_CREDITS_KEY_BCS,
  );
  if (!bytes) return null;
  const parsed = recordingCredits.RecordingCredits.parse(bytes);
  return {
    credits: mapCreditEntries(parsed.credits.contents as ParsedCreditEntry[]),
    primaryArtistIds: parsed.primary_artist_ids.contents as string[],
    featuredArtistIds: parsed.featured_artist_ids.contents as string[],
  };
}

/**
 * Fetches and parses a composition's credits. Returns `null` if no credits record
 * is attached. The work id is the `Composition` object id.
 */
export async function getCompositionCredits(
  client: ClientWithCoreApi,
  compositionId: string,
  compositionCreditsPackageId: string,
): Promise<CompositionCredits | null> {
  const bytes = await getCreditsFieldBytes(
    client,
    compositionId,
    `${compositionCreditsPackageId}::composition_credits::CompositionCreditsKey`,
    COMPOSITION_CREDITS_KEY_BCS,
  );
  if (!bytes) return null;
  const parsed = compositionCredits.CompositionCredits.parse(bytes);
  return { credits: mapCreditEntries(parsed.credits.contents as ParsedCreditEntry[]) };
}

/**
 * Fetches and parses a release's credits. Returns `null` if no credits record is
 * attached. The work id is the `Release` object id.
 */
export async function getReleaseCredits(
  client: ClientWithCoreApi,
  releaseId: string,
  releaseCreditsPackageId: string,
): Promise<ReleaseCredits | null> {
  const bytes = await getCreditsFieldBytes(
    client,
    releaseId,
    `${releaseCreditsPackageId}::release_credits::ReleaseCreditsKey`,
    RELEASE_CREDITS_KEY_BCS,
  );
  if (!bytes) return null;
  const parsed = releaseCredits.ReleaseCredits.parse(bytes);
  return { credits: mapCreditEntries(parsed.credits.contents as ParsedCreditEntry[]) };
}

// Re-export the generated BCS structs so callers can parse credits themselves
// (e.g. from a dynamic field they fetched through another path).
export {
  RecordingCredits as RecordingCreditsBcs,
  RecordingCreditsKey as RecordingCreditsKeyBcs,
} from "../contracts/recording_credits/recording_credits.js";
export {
  CompositionCredits as CompositionCreditsBcs,
  CompositionCreditsKey as CompositionCreditsKeyBcs,
} from "../contracts/composition_credits/composition_credits.js";
export {
  ReleaseCredits as ReleaseCreditsBcs,
  ReleaseCreditsKey as ReleaseCreditsKeyBcs,
} from "../contracts/release_credits/release_credits.js";
