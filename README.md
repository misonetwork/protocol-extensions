# Miso Protocol Extensions

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](#license)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> A monorepo of first-party extension packages for the [Miso protocol](https://github.com/misonetwork/miso-protocol) on [Sui](https://sui.io), maintained by Miso.

Miso keeps its core objects — `Composition`, `Recording`, `Release` — lean: only protocol-verifiable, constitutive state lives on them. Everything else is an **extension**: a standalone Move package that plugs into those objects (through their stable addresses, their admin caps, and raw `&mut UID` access) without modifying the protocol. New behavior can be added or removed without touching, or re-publishing, the core.

Each package in this repo is independent and published separately — depend on only the ones you need. **For how a given extension works, see its own `README.md`** (linked below); this page stays at the monorepo level.

## Packages

| Package | Attaches to | Summary |
|---------|-------------|---------|
| [`release_revenue_distributor`](./release_revenue_distributor) | `Release` | Splits a release's revenue across its tracks by each track's `split_bps` and forwards each share to that track's recording address. |
| [`recording_royalty_pool`](./recording_royalty_pool) | `Recording` | Cap-gated royalty pool that lets a recording's share-token holders stake and claim its inbound revenue pro-rata. |
| [`composition_royalty_pool`](./composition_royalty_pool) | `Composition` | The same stake-and-claim pool model, for compositions. |
| [`composition_recording_stake`](./composition_recording_stake) | `Composition` | Lets a composition custody, stake, and earn royalties on the recording shares it owns. |
| [`composition_credits`](./composition_credits) | `Composition` | Canonical writing-credits (attribution) standard: party-keyed songwriting / publishing credits. |
| [`recording_credits`](./recording_credits) | `Recording` | Per-party performance credits (display name + roles) plus primary/featured artist designations. |
| [`release_credits`](./release_credits) | `Release` | Top-line release billing (primary / featured artists). |
| [`recording_attribution`](./recording_attribution) | `Recording` | Opt-in generative-use licensing plus immutable per-edge attribution that routes a generated recording's revenue back to its sources. |
| [`recording_master`](./recording_master) | `Recording` | Generic, media-agnostic attachment of ingester-produced master values, namespaced by witness type and content digest. |
| [`cover_art`](./cover_art) | `Release` | Evolvable cover-art metadata (still image + optional animation) referencing Walrus storage. |
| [`genre`](./genre) | `Release` | Curated genre vocabulary plus release genre assignment (one primary + secondary genres). |
| [`streaming_links`](./streaming_links) | `Release` | External streaming-platform deep links for a release — album-level and per-track. |

## Dependencies

Extensions read Miso objects and build on a few shared primitives. Each package pulls in only what it uses. The two extension-only primitives (`royalty_pool`, `per_track`) are vendored in [`lib/`](./lib); the rest are external git dependencies.

| Dependency | Used by | Role |
|------------|---------|------|
| [`miso`](https://github.com/misonetwork/miso-protocol) | all | Core `Composition` / `Recording` / `Release` / `Track` types and admin caps |
| [`royalty_pool`](./lib/royalty_pool) | royalty pools, `composition_recording_stake`, `recording_attribution` | Stake-and-claim royalty pool primitive |
| [`per_track`](./lib/per_track) | `cover_art`, `genre`, `streaming_links` | Per-track parallel array validated against a release's tracklist |
| `hikida` | royalty pools, `composition_recording_stake`, `release_revenue_distributor` | Balance accumulator for the `redeem_*` paths |
| `partyos` | `*_credits` | Party identity for credit attribution |
| [`ori`](https://github.com/unconfirmedlabs/ori) | `cover_art` | Walrus data references |

The `miso` dependency resolves to the sibling `miso-protocol` checkout (`../../miso-protocol/move`). To build against the published protocol instead, point it at the git source:

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

- **Extensions, not forks.** These packages operate on Miso objects via their addresses and admin caps; they never modify core protocol state, so distribution and metadata models can evolve independently of the protocol.
- **Address-as-inbox.** Every composition and recording has a stable on-chain address that acts as a permanent inbox — payers need only the object ID, and funds can arrive before any pool exists; the admin folds them in later.
- **Push vs. pull.** `release_revenue_distributor` is a *push* split (revenue fans out to works at distribution time); the `*_royalty_pool` packages are *pull* claims (holders stake and withdraw over time).

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) © Miso Labs, Inc.
