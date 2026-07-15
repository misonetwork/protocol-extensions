# `cover_art`

> The evolvable `CoverArt` value type: a still image plus an optional animation, each a reference to external (Walrus) storage. The shared primitive behind release cover-art metadata.

**Layer:** `move/lib` — a primitive, not core protocol and not an extension (it attaches to nothing). It is a reusable value type composed by release extensions such as `release_cover_art`.

`CoverArt` is a plain `copy`/`drop`/`store` struct, not an object: a still image plus an optional animation, each a reference to external storage via `ori::WalrusData`. Both references must be Walrus blobs (enforced in `cover_art::new`). The format is deliberately kept in this small primitive rather than in immutable core — a new cover format (e.g. additional media) is a republish of this package or a new cover-art standard, not a republish of the frozen protocol.

## API

- **`cover_art::new(still, animated)`** — constructs a `CoverArt` from a still `WalrusData` and an optional animated `WalrusData`; asserts both are Walrus blobs.
- **`cover_art::still`** — borrows the still-image `WalrusData`.
- **`cover_art::animated`** — borrows the optional animated `WalrusData`.

## Dependencies

- **`ori`** — `WalrusData` references to off-chain (Walrus) cover-image storage.

## Build & test

```sh
sui move build
sui move test
```
