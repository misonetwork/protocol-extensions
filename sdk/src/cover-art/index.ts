// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Public facade for the Miso first-party cover-art extension (recording +
// release). Re-exports the codegen'd, type-safe Move-call builders, plus
// hand-written helpers to construct the `CoverArt` argument (via `cover_art::new`
// over `ori::walrus_data`) and to read + BCS-parse the cover-art dynamic field
// off a recording or release.
//
// Builders follow the Sui SDK thunk pattern: each returns a `(tx: Transaction) => …`
// thunk that adds commands to a caller-owned `Transaction`, so flows compose.

import type { ClientWithCoreApi } from "@mysten/sui/client";
import {
  type Transaction,
  type TransactionObjectArgument,
} from "@mysten/sui/transactions";
import type { WalrusData } from "@unconfirmed/ori";

import * as coverArt from "../contracts/cover_art/cover_art.js";
import * as recordingCoverArtMod from "../contracts/cover_art/recording_cover_art.js";
import * as releaseCoverArtMod from "../contracts/cover_art/release_cover_art.js";

// ============================================================================
// Tx-call builders, grouped by work type
// ============================================================================

/**
 * Recording cover-art Move-call builders (`recordingCoverArt.set`,
 * `recordingCoverArt.unset`, `recordingCoverArt.hasCoverArt`,
 * `recordingCoverArt.coverArt`). These take the recording's two phantom share
 * types as `typeArguments: [RecordingShare, CompositionShare]`.
 */
export const recordingCoverArt = recordingCoverArtMod;

/**
 * Release cover-art Move-call builders (`releaseCoverArt.setCover`,
 * `releaseCoverArt.unsetCover`, `releaseCoverArt.setDiscCoverArt`,
 * `releaseCoverArt.unsetDiscCoverArt`, `releaseCoverArt.hasCoverArt`,
 * `releaseCoverArt.cover`, `releaseCoverArt.hasDiscCoverArt`,
 * `releaseCoverArt.discCoverArt`). Releases are not generic, so these take no type
 * arguments.
 */
export const releaseCoverArt = releaseCoverArtMod;

// ============================================================================
// WalrusData helper (ori::walrus_data)
// ============================================================================

/**
 * Input describing a Walrus data reference to build on-chain. Mirrors the
 * `ori::walrus_data` constructors:
 * - `blob` — a standalone, unencrypted blob (`new_blob`)
 * - `encryptedBlob` — a standalone AES-encrypted blob with a Seal-sealed DEK
 *   (`new_encrypted_blob`)
 * - `quiltPatch` — a patch within a quilt (`new_quilt_patch`)
 *
 * `blobId`/`quiltId` are u256 blob ids as decimal strings (or bigints).
 */
export type WalrusDataInput =
  | { kind: "blob"; blobId: string | bigint }
  | { kind: "encryptedBlob"; blobId: string | bigint; sealedDek: Uint8Array | number[] }
  | {
      kind: "quiltPatch";
      quiltId: string | bigint;
      version: number;
      startIndex: number;
      endIndex: number;
    };

/**
 * Builds an `ori::walrus_data::WalrusData` argument. Wraps the raw `moveCall`
 * because `ori::walrus_data` is an external package and is not part of this SDK's
 * codegen surface.
 */
export function buildWalrusData(oriPackageId: string, input: WalrusDataInput) {
  return (tx: Transaction): TransactionObjectArgument => {
    switch (input.kind) {
      case "blob":
        return tx.moveCall({
          target: `${oriPackageId}::walrus_data::new_blob`,
          arguments: [tx.pure.u256(BigInt(input.blobId))],
        });
      case "encryptedBlob":
        return tx.moveCall({
          target: `${oriPackageId}::walrus_data::new_encrypted_blob`,
          arguments: [
            tx.pure.u256(BigInt(input.blobId)),
            tx.pure.vector("u8", Array.from(input.sealedDek)),
          ],
        });
      case "quiltPatch":
        return tx.moveCall({
          target: `${oriPackageId}::walrus_data::new_quilt_patch`,
          arguments: [
            tx.pure.u256(BigInt(input.quiltId)),
            tx.pure.u8(input.version),
            tx.pure.u16(input.startIndex),
            tx.pure.u16(input.endIndex),
          ],
        });
    }
  };
}

// ============================================================================
// CoverArt helper (cover_art::cover_art)
// ============================================================================

const OPTION_NONE = "0x1::option::none";
const OPTION_SOME = "0x1::option::some";

export interface BuildCoverArtParams {
  /** `cover_art` package id (where `cover_art::new` lives). */
  coverArtPackageId: string;
  /** Ori package id (where `walrus_data::new_*` live). */
  oriPackageId: string;
  /** Required still image reference. */
  still: WalrusDataInput;
  /** Optional animated cover-art reference. */
  animated?: WalrusDataInput;
}

/**
 * Builds a `cover_art::CoverArt` argument (still + optional animated) via
 * `cover_art::new`, wiring its `WalrusData` arguments through {@link buildWalrusData}.
 * Ready to pass as the `art` argument of `recordingCoverArt.set` /
 * `releaseCoverArt.setCover` / `releaseCoverArt.setDiscCoverArt`.
 */
export function buildCoverArt(params: BuildCoverArtParams) {
  const { coverArtPackageId, oriPackageId, still, animated } = params;
  return (tx: Transaction): TransactionObjectArgument => {
    const stillArg = buildWalrusData(oriPackageId, still)(tx);
    const walrusType = `${oriPackageId}::walrus_data::WalrusData`;
    const animatedArg = animated
      ? tx.moveCall({
          target: OPTION_SOME,
          typeArguments: [walrusType],
          arguments: [buildWalrusData(oriPackageId, animated)(tx)],
        })
      : tx.moveCall({ target: OPTION_NONE, typeArguments: [walrusType], arguments: [] });
    return tx.add(
      coverArt._new({ package: coverArtPackageId, arguments: [stillArg, animatedArg] }),
    );
  };
}

// ============================================================================
// Parsed cover-art record types
// ============================================================================

/** A parsed cover art: a still image and an optional animated version. */
export interface CoverArt {
  /** The still image reference. */
  still: WalrusData;
  /** The optional animated reference. */
  animated: WalrusData | null;
}

/** Parsed release cover art: a release-level cover plus per-disc covers. */
export interface ReleaseCoverArt {
  /** The release-level cover (null if unset). */
  cover: CoverArt | null;
  /** Per-disc cover art keyed by disc index. Sparse — only discs with art appear. */
  discCoverArt: Map<number, CoverArt>;
}

// ============================================================================
// Read helpers — fetch + BCS-parse the cover-art dynamic field
// ============================================================================

/**
 * Both cover-art records live under a `CoverArtKey` unit-struct key on the work's
 * UID. `CoverArtKey` is a single-field tuple struct `(bool)` defaulting to `false`,
 * so its BCS serialization is a single `0x00` byte.
 */
const COVER_ART_KEY_BCS = recordingCoverArtMod.CoverArtKey.serialize([false]).toBytes();

/** `<packageId>::recording_cover_art::CoverArtKey`, the recording DF key type. */
function recordingCoverArtKeyType(packageId: string): string {
  return `${packageId}::recording_cover_art::CoverArtKey`;
}

/** `<packageId>::release_cover_art::CoverArtKey`, the release DF key type. */
function releaseCoverArtKeyType(packageId: string): string {
  return `${packageId}::release_cover_art::CoverArtKey`;
}

/** Fetches the raw BCS bytes of a work's cover-art dynamic field value, or null if absent. */
async function getCoverArtFieldBytes(
  client: ClientWithCoreApi,
  workId: string,
  keyType: string,
): Promise<Uint8Array | null> {
  try {
    const { dynamicField } = await client.core.getDynamicField({
      parentId: workId,
      name: { type: keyType, bcs: COVER_ART_KEY_BCS },
    });
    return dynamicField.value.bcs ?? null;
  } catch {
    return null; // not-found (or unreadable) → no cover art attached
  }
}

/** A BCS-parsed `WalrusData` enum value (`{ $kind, Blob?: [...], QuiltPatch?: [...] }`). */
type ParsedWalrusData =
  | { $kind: "Blob"; Blob: [string, unknown] }
  | { $kind: "QuiltPatch"; QuiltPatch: [string, number, number, number] };

/** A BCS-parsed `CoverArt` struct value. */
type ParsedCoverArt = {
  still: ParsedWalrusData;
  animated: ParsedWalrusData | null;
};

/** Maps a BCS-parsed `WalrusData` enum into the `@unconfirmed/ori` `WalrusData` union. */
function mapWalrusData(d: ParsedWalrusData): WalrusData {
  if (d.$kind === "Blob") {
    // `Blob` is `(u256 blob_id, Confidentiality)`; only the blob id is surfaced.
    return { type: "Blob", blobId: d.Blob[0] };
  }
  const [quiltId, version, startIndex, endIndex] = d.QuiltPatch;
  return { type: "QuiltPatch", quiltId, version, startIndex, endIndex };
}

function mapCoverArt(d: ParsedCoverArt): CoverArt {
  return {
    still: mapWalrusData(d.still),
    animated: d.animated ? mapWalrusData(d.animated) : null,
  };
}

/**
 * Fetches and parses a recording's cover art. Returns `null` if none is attached.
 * The work id is the `Recording` object id.
 */
export async function getRecordingCoverArt(
  client: ClientWithCoreApi,
  recordingId: string,
  coverArtPackageId: string,
): Promise<CoverArt | null> {
  const bytes = await getCoverArtFieldBytes(
    client,
    recordingId,
    recordingCoverArtKeyType(coverArtPackageId),
  );
  if (!bytes) return null;
  return mapCoverArt(coverArt.CoverArt.parse(bytes) as ParsedCoverArt);
}

/**
 * Fetches and parses a release's cover art record (release-level cover + per-disc
 * covers). Returns `null` if no record is attached. The work id is the `Release`
 * object id.
 */
export async function getReleaseCoverArt(
  client: ClientWithCoreApi,
  releaseId: string,
  coverArtPackageId: string,
): Promise<ReleaseCoverArt | null> {
  const bytes = await getCoverArtFieldBytes(
    client,
    releaseId,
    releaseCoverArtKeyType(coverArtPackageId),
  );
  if (!bytes) return null;
  const parsed = releaseCoverArtMod.ReleaseCoverArt.parse(bytes) as {
    cover: ParsedCoverArt | null;
    disc_cover_art: { contents: { key: string; value: ParsedCoverArt }[] };
  };
  const discCoverArt = new Map<number, CoverArt>();
  for (const entry of parsed.disc_cover_art.contents) {
    discCoverArt.set(Number(entry.key), mapCoverArt(entry.value));
  }
  return {
    cover: parsed.cover ? mapCoverArt(parsed.cover) : null,
    discCoverArt,
  };
}

// Re-export the generated BCS structs so callers can parse cover art themselves
// (e.g. from a dynamic field they fetched through another path).
export { CoverArt as CoverArtBcs } from "../contracts/cover_art/cover_art.js";
export {
  ReleaseCoverArt as ReleaseCoverArtBcs,
  CoverArtKey as ReleaseCoverArtKeyBcs,
} from "../contracts/cover_art/release_cover_art.js";
export { CoverArtKey as RecordingCoverArtKeyBcs } from "../contracts/cover_art/recording_cover_art.js";
