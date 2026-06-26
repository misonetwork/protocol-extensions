# `per_track`

> A per-track parallel array: one `Data` value per track of a release, held in tracklist order. The shared primitive behind per-track release metadata (cover art, genre).

**Layer:** `move/lib` — a primitive, not core protocol and not an extension (it attaches to nothing). It is a reusable building block composed by release extensions such as `release_cover_art` and `release_genre`.

A release's tracks form a flat, ordered list — disc-major: every track of disc 0 in order, then disc 1, and so on — that is frozen at release creation. `PerTrack<Data>` is the parallel array to that list: index `i` holds the payload for the `i`-th track. `Data` is the per-track payload — `CoverArt` when every track carries one, or `Option<CoverArt>` for override-style metadata layered over an album-level default.

Construction reads the `Release` and sizes/validates the array against `total_tracks()`, so a `PerTrack` is parallel to the tracklist **by construction** — an extension cannot attach a misaligned array. Because the tracklist is frozen at release creation, that alignment holds for the release's whole life.

## API

- **`per_track::new<Data>(release, entries)`** — wraps a per-track vector in tracklist order; aborts unless its length equals `release.total_tracks()`.
- **`per_track::filled<Data>(release, value)`** — sizes to the release's track count with every track initialized to `value` (e.g. `option::none()`); the natural start for override-style metadata.
- **`per_track::length<Data>`** — the number of tracks covered.
- **`per_track::borrow<Data>`** — borrows track `i`'s payload; aborts if `i` is out of range.
- **`per_track::borrow_mut<Data>`** — mutably borrows track `i`'s payload; aborts if `i` is out of range.

## Dependencies

- **`miso`** — core protocol; `Release` (read at construction for `total_tracks()`).

## Build & test

```sh
sui move build
sui move test
```
