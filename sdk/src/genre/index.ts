// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Public facade for the Miso first-party genre extension. Re-exports the
// codegen'd, type-safe Move-call builders generated from the `genre` Move
// package, so the bindings stay in lockstep with the on-chain ABI.
//
// Two halves:
//  - Vocabulary (curator, `GenreRegistryCap`-gated): `genre._new` to add a
//    canonical genre, `genre.deriveGenreId` to resolve a genre's deterministic
//    id from its name without a round-trip.
//  - Recording self-classification (`RecordingAdminCap`-gated, attached as a
//    dynamic field): `genre.setPrimaryGenre`, `genre.addSecondaryGenre`,
//    `genre.removeSecondaryGenre`. These take the recording's two phantom share
//    types as `typeArguments: [RecordingShare, CompositionShare]`.
//  - Reads: `genre.hasGenre`, `genre.primaryGenre`, `genre.secondaryGenres`,
//    `genre.id`, `genre.name`.
//
// Builders follow the Sui SDK thunk pattern: each returns a `(tx) => …` thunk
// that adds commands to a caller-owned `Transaction`, so flows compose.

import * as genreMod from "../contracts/genre/genre.js";

export const genre = genreMod;

// BCS structs for self-parsing the genre-assignment dynamic field + events.
export const GenreBcs = genreMod.Genre;
export const GenreAssignmentBcs = genreMod.GenreAssignment;
export const GenreAssignmentKeyBcs = genreMod.GenreAssignmentKey;
