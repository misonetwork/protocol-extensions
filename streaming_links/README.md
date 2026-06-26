# `streaming_links`

> External streaming-platform deep links for a Miso release — album-level and per-track.

**Two modules.** `streaming_links::platforms` owns the **vocabulary** — one small `*Link` struct per platform plus the URL builders. `streaming_links::release_links` owns **attachment** and attaches to `miso::release::Release` as a single `ReleaseStreamingLinks` dynamic field (keyed by `StreamingLinksKey()`) on the release's `&mut UID`, gated by the `ReleaseAdminCap`.

Streaming presence is presentation, not protocol-verifiable state, so it lives on the **release** (the consumer object), not the recording — a recording carries only objective facts about its sound, never where a particular distribution of it is sold. The extension lets a frontend render "Stream on Spotify / Apple Music / …" links for the release and for any individual track.

Every platform link is `template + native id`, and only the id varies per release/track. So the templates live in code (paid for once in package bytecode) and on-chain storage holds only the ids — a Spotify album id is 22 bytes vs ~40 for the full URL. Each `*Link` struct carries *only* what is needed to rebuild that platform's URL; album-vs-track shape is chosen by which slot holds the link, so the same struct serves both levels. Universal identifiers (ISRC per recording, UPC per release) are deliberately **not** stored here — those are resolved through a separate SuiNS-backed mapping.

The release holds a single `ReleaseStreamingLinks` record: an **album-level** `PlatformLinks` bundle plus **per-track** bundles, a `PerTrack<PlatformLinks>` (one slot per track, aligned to the tracklist by construction). A track with an empty bundle inherits the album-level links at the frontend. All writes are gated by the `ReleaseAdminCap`; views are permissionless.

## Supported platforms

| Platform | Album URL | Track URL |
|----------|-----------|-----------|
| Spotify | `open.spotify.com/album/{id}` | `open.spotify.com/track/{id}` |
| Apple Music | `music.apple.com/{storefront}/album/{id}` | `…/album/{id}?i={track}` |
| YouTube Music | `music.youtube.com/playlist?list={id}` | `music.youtube.com/watch?v={id}` |
| Amazon Music | `music.amazon.com/albums/{asin}` | `…?trackAsin={asin}` |
| Tidal | `tidal.com/browse/album/{id}` | `tidal.com/browse/track/{id}` |
| Deezer | `www.deezer.com/album/{id}` | `www.deezer.com/track/{id}` |
| SoundCloud | `soundcloud.com/{user}/sets/{slug}` | `soundcloud.com/{user}/{slug}` |
| Bandcamp | `{subdomain}.bandcamp.com/album/{slug}` | `{subdomain}.bandcamp.com/track/{slug}` |

Apple Music and Amazon Music are the two platforms whose *track* URL needs the album context; their structs carry an optional `track_id` and the builder emits the album form when it is absent, the track form when it is set.

Adding a new platform is a fresh package (the struct layout is frozen once published): the client reads the old record via the views, sets the equivalent record on the new extension with the extra platform, and `clear`s the old one — all in one PTB. No on-chain migration, no dependency between the packages.

## Entry points

- **`platforms::new_spotify` / `new_apple_music_album` / `new_apple_music_track` / `new_youtube_music` / `new_amazon_music_album` / `new_amazon_music_track` / `new_tidal` / `new_deezer` / `new_soundcloud` / `new_bandcamp`** — construct a single platform link, asserting its identifiers are non-empty.
- **`platforms::empty` + `with_*`** — build a `PlatformLinks` bundle fluently, e.g. `empty().with_spotify(..).with_apple_music(..)`.
- **`release_links::set_release_links`** — cap-gated; sets or replaces the album-level bundle (lazily initializing the record). Emits `ReleaseLinksSetEvent`.
- **`release_links::set_track_links`** — cap-gated; sets or replaces a track's bundle by tracklist index, aborting if the index is out of range. Emits `TrackLinksSetEvent`.
- **`release_links::clear_track`** — cap-gated; resets a track's bundle to empty (the track falls back to the album-level links).
- **`release_links::clear`** — cap-gated; removes the whole record (reclaims the storage rebate).

## Views

- **`platforms::*_url`** — the canonical URL for a link (`spotify_album_url`, `spotify_track_url`, `apple_music_url`, `youtube_music_album_url`, `youtube_music_track_url`, `amazon_music_url`, `tidal_album_url`, `tidal_track_url`, `deezer_album_url`, `deezer_track_url`, `soundcloud_set_url`, `soundcloud_track_url`, `bandcamp_album_url`, `bandcamp_track_url`).
- **`platforms::spotify` / `apple_music` / … / `bandcamp`** — a bundle's `Option<*Link>` for each platform; **`is_empty`** — whether a bundle holds no links.
- **`release_links::has_links`** — whether a record is attached to the release.
- **`release_links::release_links`** — the album-level `Option<PlatformLinks>`.
- **`release_links::track_links`** — a track's own `Option<PlatformLinks>` by index; aborts if the index is out of range (when a record exists).

## Dependencies

- **`miso`** — core protocol; `release_links` attaches to `Release` via its admin cap and `uid_mut`/`uid`.
- **`per_track`** — the `PerTrack<Data>` primitive backing the per-track bundles.

## Build & test

```sh
sui move build
sui move test
```
