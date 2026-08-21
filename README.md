# Miso Protocol Extensions

First-party data-model extensions for
[`misonetwork/protocol`](https://github.com/misonetwork/protocol) on Sui.

Miso keeps `Composition`, `Recording`, and `Release` focused on constitutive
protocol state. An extension adds optional typed data as a dynamic field on one
of those objects. Writes require the object's matching admin capability through
its cap-gated `uid_mut`; reads are permissionless.

Extensions do not custody capabilities, automate administrative authority, or
route economic value. Those responsibilities belong to separate layers:

| Repository | Responsibility |
|------------|----------------|
| [`misofm/vault`](https://github.com/misofm/vault) | Generic capability custody and temporary exact-return leases. |
| [`misofm/vault-plugins`](https://github.com/misofm/vault-plugins) | Installed business logic that exercises a custodied protocol admin capability. |
| [`misonetwork/protocol-utilities`](https://github.com/misonetwork/protocol-utilities) | Standalone protocol infrastructure that neither attaches data nor borrows authority. |

Each directory in this repository is an independently versioned and published
Move package. Applications should depend only on the extensions they use.

## Packages

| Package | Target | Purpose |
|---------|--------|---------|
| [`composition_credits`](./composition_credits) | Composition | Songwriting and publishing attribution keyed by Party ID. |
| [`recording_advisory`](./recording_advisory) | Recording | Explicit, not-explicit, or cleaned advisory classification. |
| [`recording_credits`](./recording_credits) | Recording | Performance and production credits with primary and featured artist designations. |
| [`recording_language`](./recording_language) | Recording | Ordered ISO 639-1 language metadata; an empty list explicitly denotes instrumental content. |
| [`recording_master_reference`](./recording_master_reference) | Recording | Transitional, unverified Walrus reference to a master-audio blob. |
| [`recording_preview`](./recording_preview) | Recording | Public Walrus reference to a preview-audio blob. |
| [`release_cover_art`](./release_cover_art) | Release | Release-level cover art with optional per-track overrides. |
| [`release_credits`](./release_credits) | Release | Primary and featured top-line artist billing keyed by Party ID. |
| [`release_description`](./release_description) | Release | Bounded free-text editorial description. |
| [`release_dsp_link`](./release_dsp_link) | Release | Typed release and per-track identifiers for supported streaming services. |
| [`release_genre`](./release_genre) | Release | Primary, secondary, and optional per-track genre metadata with no timing or economic policy. |
| [`release_kind`](./release_kind) | Release | Bounded free-text release classification such as Album, EP, or Mixtape. |
| [`release_snapshot_bundle`](./release_snapshot_bundle) | Release | Write-once Walrus reference to a curated snapshot bundle. |

## Usage

Reference an extension by repository subdirectory and exact commit:

```toml
[dependencies]
release_genre = { git = "https://github.com/misonetwork/protocol-extensions.git", subdir = "release_genre", rev = "<40-character-commit>" }
```

Each package's `Move.toml` pins its own protocol and supporting dependencies.
If the protocol admin capability is held in a Vault, the `VaultAdminCap` holder
can use `borrow_as_admin`, call the extension's public write function, and
return the capability in the same programmable transaction block.

Published package identities are recorded per package in `Published.toml` when
the current source is upgrade-compatible with that deployment. The simplified
`release_genre` package intentionally requires a fresh package ID.

## Development

Run commands from the extension package directory:

```sh
cd release_genre
sui move build
sui move test --coverage
```

The test suites include production-shaped `sui::test_scenario` flows for shared
protocol objects and focused invariant and authorization tests.

## License

[Apache-2.0](./LICENSE)
