# Miso Protocol Extensions

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](#license)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> A monorepo of first-party extension packages for the [Miso protocol](https://github.com/misonetwork/miso-protocol) on [Sui](https://sui.io), maintained by Miso.

Miso keeps its core objects — `Composition`, `Recording`, `Release` — lean: only protocol-verifiable, constitutive state lives on them. **Extensions** add data to those objects through their cap-gated `&mut UID` surface without changing who controls them. **Plugins** add business logic by installing on a [vault](https://github.com/misofm/vault) that custodies the object's admin cap; an installed plugin must present its private, transaction-local witness before the vault will expose the object's `&mut UID`. **Utilities** provide standalone protocol infrastructure without attaching a schema or taking custody of authority.

In short: extensions extend the data model; plugins extend the authority model;
utilities support the protocol without extending either.

First-party plugin packages are maintained separately in
[`misofm/vault-plugins`](https://github.com/misofm/vault-plugins) while their
review and scoring model is developed. Every plugin package has one canonical
installation identity at `0xpkg::witness::Witness`. The type has only `drop`,
and a package-only `witness::new()` lets the plugin's internal modules construct
it without exposing construction to downstream packages.

Standalone protocol utilities, including the canonical release derivation
registry, live in
[`misonetwork/protocol-utilities`](https://github.com/misonetwork/protocol-utilities).

Each package in this repo is independent and published separately — depend on only the ones you need. **For how a given extension works, see its own `README.md`** (linked below); this page stays at the monorepo level.

## Packages

| Package | Attaches to | Summary |
|---------|-------------|---------|
| [`composition_credits`](./composition_credits) | `Composition` | Canonical writing-credits (attribution) standard: party-keyed songwriting / publishing credits. |
| [`recording_credits`](./recording_credits) | `Recording` | Per-party performance credits (display name + roles) plus primary/featured artist designations. |
| [`release_credits`](./release_credits) | `Release` | Top-line release billing (primary / featured artists). |
| [`recording_preview`](./recording_preview) | `Recording` | Public audio preview clip — a single Walrus blob reference, cap-gated writes, no ingestion/attestation in V1. |
| [`cover_art`](./cover_art) | `Release` | Evolvable cover-art metadata (still image + optional animation) referencing Walrus storage. |
| [`release_snapshot_bundle`](./release_snapshot_bundle) | `Release` | Write-once pointer to the release's snapshot-bundle quilt (curated bonus material on Walrus) — no unset or replace, so a buyer's bundle can never be swapped. |
| [`release_genre`](./release_genre) | `Release` | Pure release metadata: one primary genre, secondary genres, and optional per-track primary overrides. |
| [`release_description`](./release_description) | `Release` | The release's own words about itself — one free-text slot (≤ 8 KB), set and cleared under the release admin cap. |
| [`release_dsp_link`](./release_dsp_link) | `Release` | External DSP (streaming platform) deep links for a release — album-level and per-track, one built-in enum covering all 8 supported platforms (Spotify, Apple Music, Amazon Music, Bandcamp, Deezer, SoundCloud, Tidal, YouTube Music). |

## Dependencies

Extensions read Miso objects and build on independently versioned packages.
Each package pulls in only what it uses and pins the exact dependency revision
in its `Move.toml`.

| Dependency | Used by | Role |
|------------|---------|------|
| [`miso`](https://github.com/misonetwork/miso-protocol) | all | Core `Composition` / `Recording` / `Release` / `Track` types and admin caps |
| [`per_track`](https://github.com/misonetwork/per-track) | `cover_art`, `genre`, `release_dsp_link` | Per-track parallel array validated against a release's tracklist |
| `partyos` | `*_credits` | Party identity for credit attribution |
| [`ori`](https://github.com/unconfirmedlabs/ori) | `cover_art`, `recording_preview`, `release_snapshot_bundle` | Walrus data references |

The `miso` dependency is pinned to the protocol repository by commit:

```toml
miso = { git = "https://github.com/misonetwork/protocol.git", rev = "<40-character-commit>" }
```

## TypeScript SDK

[`sdk/`](./sdk) publishes [`@misonetwork/miso-extensions`](./sdk) — typed query helpers and transaction builders that mirror the Move ABI of the extensions, exposed under per-extension subpath exports:

| Import | Covers |
|--------|--------|
| `@misonetwork/miso-extensions/credits` | `composition_credits`, `recording_credits`, `release_credits` |
| `@misonetwork/miso-extensions/cover-art` | `cover_art` |
| `@misonetwork/miso-extensions/genre` | `genre` |

The core protocol's own bindings live in [`@misonetwork/miso`](https://github.com/misonetwork/miso-protocol); this package never depends on them — each extension module is self-contained.

## Build & test

Every directory is a standalone Move package. From any package directory:

```sh
sui move build
sui move test
```

For the SDK:

```sh
cd sdk
bun install
bun run typecheck
bun run codegen   # regenerate ABI bindings from the sibling Move packages
```

## Design notes

- **Extensions and plugins, not forks.** These packages operate on Miso objects through their stable public interfaces; they never modify core protocol definitions, so data schemas and administration models can evolve independently of the protocol.
- **Separate authority layer.** Economic and administrative behavior that
  borrows a protocol admin capability lives in
  [`misofm/vault-plugins`](https://github.com/misofm/vault-plugins), not in this
  data-extension repository.
- **Separate utility layer.** Standalone coordination objects that neither
  attach data nor borrow an admin capability live in
  [`misonetwork/protocol-utilities`](https://github.com/misonetwork/protocol-utilities).

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) © Miso Labs, Inc.
