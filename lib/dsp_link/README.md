# `dsp_link` — Digital Service Provider links

> External streaming links for a Miso release — one small package per DSP, a
> shared generic primitive, and a generic release-attachment. **DSP** = Digital
> Service Provider (Spotify, Apple Music, Amazon Music, …).

A release's "Stream on Spotify / Apple Music / …" links, modelled so that adding
a new DSP is a **new package** — never a migration of existing records, and never
a change to the core. Streaming presence is presentation, not protocol-verifiable
state, so it lives on the **release** (the consumer object), not the recording.

## Three layers

| Layer | Package(s) | Depends on | Role |
|-------|-----------|------------|------|
| Primitive | `dsp_link` (`lib/`) | Sui only | `DspLink<Data>` — a typed link wrapper + the dynamic-field machinery to store one per `Data` type on any `UID`. Protocol-agnostic. |
| Payloads | `release_dsp_link_spotify`, `release_dsp_link_apple_music`, `release_dsp_link_amazon_music`, `release_dsp_link_tidal`, `release_dsp_link_deezer`, `release_dsp_link_youtube_music`, `release_dsp_link_soundcloud`, `release_dsp_link_bandcamp` | `dsp_link` | Each defines one DSP's native-id `*Data` struct + constructor + accessors. Tiny, independent, `miso`-free. |
| Attachment | `release_dsp_link` | `miso`, `per_track`, `dsp_link` | Generic over `Data`: album-level link per DSP + per-track links, cap-gated, with events. |

The primitive operates on a raw `&mut UID`, which is what keeps it free of any
`miso` dependency — the attachment passes `release.uid_mut(cap)` into it.

## Why this shape

- **Store ids, never URLs.** A `*Data` holds only a DSP's native id(s) (a Spotify
  album id is 22 bytes vs ~40 for the URL). The public URL is rebuilt **client-side**
  from `template + id`, using the table below as the spec. This also insulates
  stored records from URL-format churn — if a DSP reshapes its URLs, clients update
  their templates with no package upgrade and no record migration.
- **One field per DSP.** Each DSP is stored under `DspLinkKey<Data>`, whose
  `phantom Data` makes every DSP a distinct dynamic field on the release. Adding a
  DSP never rewrites another's record.
- **Type-safe and generic.** `DspLink<SpotifyData>` keeps the Spotify accessors;
  the attachment is written once, generic over `Data`. (`Data: copy + drop + store`
  — the canonical "plain value data" bound; a streaming id is always copyable
  metadata.)
- **Independent packages.** A DSP package can be authored/published on its own
  cadence, and third parties can add their own DSP packages without touching the
  core. Universal identifiers (ISRC per recording, UPC per release) are deliberately
  **not** here — those resolve through a separate SuiNS-backed mapping.

## Supported DSPs

These are the URL shapes clients build against; the chain stores only the
bracketed ids. Album-vs-track is chosen by **which slot** holds the link (the
release-level link vs a per-track link), so a single-id payload serves both.

| DSP | Album URL | Track URL |
|-----|-----------|-----------|
| Spotify | `open.spotify.com/album/{id}` | `open.spotify.com/track/{id}` |
| Apple Music | `music.apple.com/{storefront}/album/{album_id}` | `…/album/{album_id}?i={track_id}` |
| Amazon Music | `music.amazon.com/albums/{album_id}` | `…?trackAsin={track_id}` |
| Tidal | `tidal.com/album/{id}` | `tidal.com/track/{id}` |
| Deezer | `www.deezer.com/album/{id}` | `www.deezer.com/track/{id}` |
| YouTube Music | `music.youtube.com/playlist?list={id}` | `music.youtube.com/watch?v={id}` |
| SoundCloud | `soundcloud.com/{user}/sets/{slug}` | `soundcloud.com/{user}/{slug}` |
| Bandcamp | `{subdomain}.bandcamp.com/album/{slug}` | `{subdomain}.bandcamp.com/track/{slug}` |

Apple Music and Amazon Music are the two DSPs whose *track* URL needs the album
context, so their payloads carry an optional `track_id` (`new_album` vs
`new_track`); the others take a single id (or `(user, slug)` / `(subdomain, slug)`).

## Usage

A client composes a payload package with the attachment in one PTB:

```move
// Album-level Spotify link.
release_dsp_link::set_release_link(
    release, cap, release_dsp_link_spotify::new(b"3xTbtTM3BSRIGxzWSMaEpc".to_string()),
);

// A per-track Apple Music link on track index 2.
release_dsp_link::set_track_link(
    release, cap, 2,
    release_dsp_link_apple_music::new_track(b"us".to_string(), b"1440783617".to_string(), b"1440783619".to_string()),
);

// Read back (permissionless view) → Option<DspLink<SpotifyData>>.
let link = release_dsp_link::release_link<release_dsp_link_spotify::SpotifyData>(release);
// then `link.data().id()` → the Spotify id, to build the URL client-side.
```

`release_dsp_link` API (each generic over a DSP `Data`):
`set_release_link` / `clear_release_link`, `set_track_link` / `clear_track_link` /
`clear_track_links`, and views `has_release_link` / `release_link` / `track_link`.
All writes are gated by the `ReleaseAdminCap`; views are permissionless.

## Build & test

Each package builds and tests on its own:

```sh
cd lib/dsp_link && sui move test
cd release_dsp_link && sui move test
cd release_dsp_link_spotify && sui move test   # …and each other release_dsp_link_* package
```
