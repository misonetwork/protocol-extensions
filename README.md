# Miso Protocol Extensions

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](#license)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> A monorepo of first-party extension packages for the [Miso protocol](https://github.com/misonetwork/miso-protocol) on [Sui](https://sui.io), maintained by Miso.

Miso keeps its core objects — `Composition`, `Recording`, `Release` — lean: only protocol-verifiable, constitutive state lives on them. **Extensions** add data to those objects through their cap-gated `&mut UID` surface without changing who controls them. **Plugins** add business logic by installing on a [vault](https://github.com/misofm/vault) that custodies the object's admin cap; an installed plugin must present its private, transaction-local witness before the vault will expose the object's `&mut UID`. **Services** compose protocol objects and economic primitives without attaching a schema or taking custody of authority.

In short: extensions extend the data model; plugins extend the authority model.

First-party plugin packages are maintained separately in a private repository
while their review and scoring model is developed. Every plugin package has
one canonical installation identity at `0xpkg::witness::Witness`. The type has
only `drop`, and a package-only `witness::new()` lets the plugin's internal
modules construct it without exposing construction to downstream packages.

Each package in this repo is independent and published separately — depend on only the ones you need. **For how a given extension works, see its own `README.md`** (linked below); this page stays at the monorepo level.

## Packages

| Package | Attaches to | Summary |
|---------|-------------|---------|
| [`release_revenue_distributor`](./release_revenue_distributor) | `Release` | Splits a release's revenue across its tracks by each track's `split_bps` and forwards each share to the derived address of that track's recording royalty pool. |
| [`recording_royalty_pool`](./recording_royalty_pool) | `Recording` | Cap-gated royalty pool that lets a recording's share-token holders stake and claim its inbound revenue pro-rata. |
| [`composition_royalty_pool`](./composition_royalty_pool) | `Composition` | The same stake-and-claim pool model, for compositions. |
| [`composition_routed_stake`](./composition_routed_stake) | `Composition` | Lets a composition custody and earn on the recording shares it owns, with earnings permissionlessly swept into the composition's own royalty pool. |
| [`composition_credits`](./composition_credits) | `Composition` | Canonical writing-credits (attribution) standard: party-keyed songwriting / publishing credits. |
| [`recording_credits`](./recording_credits) | `Recording` | Per-party performance credits (display name + roles) plus primary/featured artist designations. |
| [`release_credits`](./release_credits) | `Release` | Top-line release billing (primary / featured artists). |
| [`recording_preview`](./recording_preview) | `Recording` | Public audio preview clip — a single Walrus blob reference, cap-gated writes, no ingestion/attestation in V1. |
| [`cover_art`](./cover_art) | `Release` | Evolvable cover-art metadata (still image + optional animation) referencing Walrus storage. |
| [`release_snapshot_bundle`](./release_snapshot_bundle) | `Release` | Write-once pointer to the release's snapshot-bundle quilt (curated bonus material on Walrus) — no unset or replace, so a buyer's bundle can never be swapped. |
| [`genre`](./genre) | `Release` | Curated genre vocabulary plus release genre assignment (one primary + secondary genres). |
| [`release_description`](./release_description) | `Release` | The release's own words about itself — one free-text slot (≤ 8 KB), set and cleared under the release admin cap. |
| [`release_dsp_link`](./release_dsp_link) | `Release` | External DSP (streaming platform) deep links for a release — album-level and per-track, one built-in enum covering all 8 supported platforms (Spotify, Apple Music, Amazon Music, Bandcamp, Deezer, SoundCloud, Tidal, YouTube Music). |

## Dependencies

Extensions read Miso objects and build on a few shared primitives. Each package pulls in only what it uses. The extension-only primitives (`royalty_pool`, `routed_stake`, `per_track`) are vendored in [`lib/`](./lib); the rest are external git dependencies.

| Dependency | Used by | Role |
|------------|---------|------|
| [`miso`](https://github.com/misonetwork/miso-protocol) | all | Core `Composition` / `Recording` / `Release` / `Track` types and admin caps |
| [`royalty_pool`](./lib/royalty_pool) | royalty pools, `composition_routed_stake` | Stake-and-claim royalty pool primitive |
| [`routed_stake`](./lib/routed_stake) | `composition_routed_stake` | Shared stake whose rewards are committed to its parent's royalty pool |
| [`per_track`](./lib/per_track) | `cover_art`, `genre`, `release_dsp_link` | Per-track parallel array validated against a release's tracklist |
| `hikida` | royalty pools, `composition_routed_stake`, `release_revenue_distributor` | Balance accumulator for the `redeem_*` paths |
| `partyos` | `*_credits` | Party identity for credit attribution |
| [`ori`](https://github.com/unconfirmedlabs/ori) | `cover_art`, `recording_preview`, `release_snapshot_bundle` | Walrus data references |

The `miso` dependency resolves to the sibling `miso-protocol` checkout (`../../miso-protocol`). To build against the published protocol instead, point it at the git source:

```toml
miso = { git = "https://github.com/misonetwork/miso-protocol.git", subdir = "move", rev = "main" }
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
- **Address-as-inbox.** Every composition and recording has a stable on-chain address that acts as a permanent inbox — payers need only the object ID, and funds can arrive before any pool exists; the admin folds them in later.
- **Push vs. pull.** `release_revenue_distributor` is a *push* split (revenue fans out to works at distribution time); the `*_royalty_pool` packages are *pull* claims (holders stake and withdraw over time).

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) © Miso Labs, Inc.
