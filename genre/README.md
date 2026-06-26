# `genre`

> Curated genre vocabulary plus release/track genre assignment for Miso.

**Two modules.** `genre::genre` owns the **vocabulary** — frozen `Genre` objects. `genre::release_genre` owns **assignment** and attaches to `miso::release::Release` as a single `ReleaseGenre` dynamic field (keyed by `GenreAssignmentKey()`) on the release's `&mut UID`, gated by the `ReleaseAdminCap`.

Genre is a classification rather than protocol-verifiable state, so it lives in an extension instead of core. It is assigned on the **release** (the consumer object), not the recording — a recording carries only objective facts about its sound, never an opinion on how it is presented or classified.

The **vocabulary** is a set of `Genre` objects created only by a `GenreRegistryCap` holder and derived from the shared `GenreRegistry` by canonical name (`GenreKey(name)`), so each name maps to one deterministic object id and re-creating a name aborts (automatic dedup). Names must be non-empty, at most 64 bytes, and consist only of `A`-`Z` and `_` (e.g. `HIP_HOP`); each `Genre` is frozen on creation.

**Assignment** gives a release one album-level primary genre and up to 5 secondary genres (which must differ from the primary and each other), plus optional per-track primary overrides — a `PerTrack<Option<ID>>`, one slot per track, aligned to the tracklist by construction. A track's effective primary genre resolves as its override if set, else the album primary. Changing an already-set album primary requires at least `MIN_PRIMARY_GENRE_EPOCHS` (30 epochs, ~30 days) since it was last set; the first set is free. Per-track overrides are display refinements and are not locked. All assignments reference `Genre` ids by value and do not hold the objects.

## Entry points

- **`genre::new`** — cap-gated (`GenreRegistryCap`). Validates the name, claims a derived `Genre` from the registry, freezes it, and emits `GenreCreatedEvent`. Aborts if the name is already in the vocabulary.
- **`release_genre::set_primary_genre`** — gated by `ReleaseAdminCap`. Sets or replaces the album primary genre, recording the current epoch. First set creates the `ReleaseGenre` field; replacing an existing primary aborts unless ≥ 30 epochs have elapsed (`EPrimaryGenreLocked`). Emits `PrimaryGenreSetEvent`.
- **`release_genre::add_secondary_genre`** / **`remove_secondary_genre`** — gated by `ReleaseAdminCap`. Add/remove an album secondary genre. Requires a primary; rejects a secondary equal to the primary, duplicates, and counts at/above `MAX_SECONDARY_GENRES` (5).
- **`release_genre::set_track_primary_genre`** / **`unset_track_primary_genre`** — gated by `ReleaseAdminCap`. Set/clear a track's primary-genre override by tracklist index. Requires the album primary; aborts if the index is out of range.

## Views

- **`genre::derive_genre_id`** — the object id a `Genre` with a given name would have, without creating it.
- **`genre::id`** / **`genre::name`** — a `Genre`'s object id / canonical name.
- **`release_genre::has_genre`** — whether the release has a genre assignment.
- **`release_genre::primary_genre`** / **`secondary_genres`** — the album primary `Option<ID>` / secondary `vector<ID>`.
- **`release_genre::track_primary_genre`** — a track's effective primary genre (override if set, else the album primary).

## Dependencies

- **`miso`** — core protocol; `release_genre` attaches to `Release` via its admin cap and `uid_mut`/`uid`.
- **`per_track`** — the `PerTrack<Data>` primitive backing the per-track genre overrides.

## Build & test

```sh
sui move build
sui move test
```
