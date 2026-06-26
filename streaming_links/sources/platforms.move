// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Streaming-platform deep links — the vocabulary behind the release streaming
/// extension. One small `*Link` struct per platform, each carrying *only* the
/// native identifier(s) needed to rebuild that platform's URL, never the full
/// URL itself.
///
/// Every platform link is `template + native id`, and only the id varies per
/// release/track. So the templates live here in code (shared, paid for once in
/// package bytecode) and on-chain storage holds just the ids. A Spotify album
/// id is 22 bytes; the full URL is ~40 — storing the id and rebuilding the URL
/// roughly halves the per-link cost. Album-vs-track URL shape is chosen by
/// *which slot* holds the link (the release-level set vs a per-track set), so
/// the same `*Link` struct serves both levels.
///
/// Universal identifiers (ISRC per recording, UPC per release) are deliberately
/// *not* here — those are resolved through a separate SuiNS-backed mapping. This
/// module is purely about explicit per-platform deep links.
///
/// Two platforms need the album context to address a track: Apple Music
/// (`/album/{albumId}?i={trackId}`) and Amazon Music (`/albums/{albumId}?
/// trackAsin={trackId}`). Their structs carry an optional `track_id`; when set,
/// the URL builder emits the track form, otherwise the album form.
module streaming_links::platforms;

use std::string::String;

// === Errors ===

/// A required identifier (id, slug, storefront, …) was empty.
const EEmptyIdentifier: u64 = 0;

// === Per-platform link structs ===

/// Spotify — `open.spotify.com/album/{id}` / `open.spotify.com/track/{id}`.
/// `id` is a 22-char base62 album id at release level, a track id per track.
public struct SpotifyLink has copy, drop, store {
    id: String,
}

/// Apple Music — `music.apple.com/{storefront}/album/{album_id}` for the album,
/// `…?i={track_id}` for a track. `storefront` is the two-letter region (e.g.
/// `us`); a track link needs the album id too, so it is always present.
public struct AppleMusicLink has copy, drop, store {
    storefront: String,
    album_id: String,
    track_id: Option<String>,
}

/// YouTube Music — album is a playlist (`music.youtube.com/playlist?list={id}`),
/// a track is a video (`music.youtube.com/watch?v={id}`). `id` holds the
/// playlist id at release level, the video id per track.
public struct YouTubeMusicLink has copy, drop, store {
    id: String,
}

/// Amazon Music — `music.amazon.com/albums/{album_id}` for the album,
/// `…?trackAsin={track_id}` for a track. Ids are ASINs (e.g. `B0064UPU4G`).
public struct AmazonMusicLink has copy, drop, store {
    album_id: String,
    track_id: Option<String>,
}

/// Tidal — `tidal.com/browse/album/{id}` / `tidal.com/browse/track/{id}`.
public struct TidalLink has copy, drop, store {
    id: String,
}

/// Deezer — `deezer.com/album/{id}` / `deezer.com/track/{id}`.
public struct DeezerLink has copy, drop, store {
    id: String,
}

/// SoundCloud — slug-addressed, not numeric: an album/playlist is
/// `soundcloud.com/{user}/sets/{slug}`, a track is `soundcloud.com/{user}/{slug}`.
public struct SoundCloudLink has copy, drop, store {
    user: String,
    slug: String,
}

/// Bandcamp — artist subdomain + slug: an album is
/// `{subdomain}.bandcamp.com/album/{slug}`, a track is
/// `{subdomain}.bandcamp.com/track/{slug}`.
public struct BandcampLink has copy, drop, store {
    subdomain: String,
    slug: String,
}

/// A bundle of platform links for one entity (a release, or a single track).
/// Each platform is `Option`-wrapped: absent ones cost a single tag byte. The
/// same type is used at both levels — the release-level set and every per-track
/// set — because a `*Link` struct is level-agnostic.
public struct PlatformLinks has copy, drop, store {
    spotify: Option<SpotifyLink>,
    apple_music: Option<AppleMusicLink>,
    youtube_music: Option<YouTubeMusicLink>,
    amazon_music: Option<AmazonMusicLink>,
    tidal: Option<TidalLink>,
    deezer: Option<DeezerLink>,
    soundcloud: Option<SoundCloudLink>,
    bandcamp: Option<BandcampLink>,
}

// === Link constructors ===

public fun new_spotify(id: String): SpotifyLink {
    assert!(!id.is_empty(), EEmptyIdentifier);
    SpotifyLink { id }
}

/// An Apple Music album link (no `?i=` track selector).
public fun new_apple_music_album(storefront: String, album_id: String): AppleMusicLink {
    assert!(!storefront.is_empty() && !album_id.is_empty(), EEmptyIdentifier);
    AppleMusicLink { storefront, album_id, track_id: option::none() }
}

/// An Apple Music track link — addresses `track_id` within its `album_id`.
public fun new_apple_music_track(
    storefront: String,
    album_id: String,
    track_id: String,
): AppleMusicLink {
    assert!(
        !storefront.is_empty() && !album_id.is_empty() && !track_id.is_empty(),
        EEmptyIdentifier,
    );
    AppleMusicLink { storefront, album_id, track_id: option::some(track_id) }
}

public fun new_youtube_music(id: String): YouTubeMusicLink {
    assert!(!id.is_empty(), EEmptyIdentifier);
    YouTubeMusicLink { id }
}

/// An Amazon Music album link.
public fun new_amazon_music_album(album_id: String): AmazonMusicLink {
    assert!(!album_id.is_empty(), EEmptyIdentifier);
    AmazonMusicLink { album_id, track_id: option::none() }
}

/// An Amazon Music track link — addresses `track_id` within its `album_id`.
public fun new_amazon_music_track(album_id: String, track_id: String): AmazonMusicLink {
    assert!(!album_id.is_empty() && !track_id.is_empty(), EEmptyIdentifier);
    AmazonMusicLink { album_id, track_id: option::some(track_id) }
}

public fun new_tidal(id: String): TidalLink {
    assert!(!id.is_empty(), EEmptyIdentifier);
    TidalLink { id }
}

public fun new_deezer(id: String): DeezerLink {
    assert!(!id.is_empty(), EEmptyIdentifier);
    DeezerLink { id }
}

public fun new_soundcloud(user: String, slug: String): SoundCloudLink {
    assert!(!user.is_empty() && !slug.is_empty(), EEmptyIdentifier);
    SoundCloudLink { user, slug }
}

public fun new_bandcamp(subdomain: String, slug: String): BandcampLink {
    assert!(!subdomain.is_empty() && !slug.is_empty(), EEmptyIdentifier);
    BandcampLink { subdomain, slug }
}

// === PlatformLinks builder ===

/// An empty bundle — no platform links set.
public fun empty(): PlatformLinks {
    PlatformLinks {
        spotify: option::none(),
        apple_music: option::none(),
        youtube_music: option::none(),
        amazon_music: option::none(),
        tidal: option::none(),
        deezer: option::none(),
        soundcloud: option::none(),
        bandcamp: option::none(),
    }
}

public fun with_spotify(mut self: PlatformLinks, link: SpotifyLink): PlatformLinks {
    self.spotify = option::some(link);
    self
}

public fun with_apple_music(mut self: PlatformLinks, link: AppleMusicLink): PlatformLinks {
    self.apple_music = option::some(link);
    self
}

public fun with_youtube_music(mut self: PlatformLinks, link: YouTubeMusicLink): PlatformLinks {
    self.youtube_music = option::some(link);
    self
}

public fun with_amazon_music(mut self: PlatformLinks, link: AmazonMusicLink): PlatformLinks {
    self.amazon_music = option::some(link);
    self
}

public fun with_tidal(mut self: PlatformLinks, link: TidalLink): PlatformLinks {
    self.tidal = option::some(link);
    self
}

public fun with_deezer(mut self: PlatformLinks, link: DeezerLink): PlatformLinks {
    self.deezer = option::some(link);
    self
}

public fun with_soundcloud(mut self: PlatformLinks, link: SoundCloudLink): PlatformLinks {
    self.soundcloud = option::some(link);
    self
}

public fun with_bandcamp(mut self: PlatformLinks, link: BandcampLink): PlatformLinks {
    self.bandcamp = option::some(link);
    self
}

// === PlatformLinks accessors ===

public fun spotify(self: &PlatformLinks): Option<SpotifyLink> { self.spotify }

public fun apple_music(self: &PlatformLinks): Option<AppleMusicLink> { self.apple_music }

public fun youtube_music(self: &PlatformLinks): Option<YouTubeMusicLink> { self.youtube_music }

public fun amazon_music(self: &PlatformLinks): Option<AmazonMusicLink> { self.amazon_music }

public fun tidal(self: &PlatformLinks): Option<TidalLink> { self.tidal }

public fun deezer(self: &PlatformLinks): Option<DeezerLink> { self.deezer }

public fun soundcloud(self: &PlatformLinks): Option<SoundCloudLink> { self.soundcloud }

public fun bandcamp(self: &PlatformLinks): Option<BandcampLink> { self.bandcamp }

/// Whether the bundle holds no platform links at all.
public fun is_empty(self: &PlatformLinks): bool {
    self.spotify.is_none()
        && self.apple_music.is_none()
        && self.youtube_music.is_none()
        && self.amazon_music.is_none()
        && self.tidal.is_none()
        && self.deezer.is_none()
        && self.soundcloud.is_none()
        && self.bandcamp.is_none()
}

// === URL builders ===
//
// Pure, deterministic reconstructions of each platform's public URL from the
// stored ids. Frontends usually decode the struct over RPC and build these
// client-side; the on-chain builders are the canonical spec of each format and
// are available to other Move consumers.

public fun spotify_album_url(self: &SpotifyLink): String {
    let mut url = b"https://open.spotify.com/album/".to_string();
    url.append(self.id);
    url
}

public fun spotify_track_url(self: &SpotifyLink): String {
    let mut url = b"https://open.spotify.com/track/".to_string();
    url.append(self.id);
    url
}

/// Builds the album URL, or — when `track_id` is set — the track URL with the
/// `?i=` selector.
public fun apple_music_url(self: &AppleMusicLink): String {
    let mut url = b"https://music.apple.com/".to_string();
    url.append(self.storefront);
    url.append(b"/album/".to_string());
    url.append(self.album_id);
    if (self.track_id.is_some()) {
        url.append(b"?i=".to_string());
        url.append(*self.track_id.borrow());
    };
    url
}

public fun youtube_music_album_url(self: &YouTubeMusicLink): String {
    let mut url = b"https://music.youtube.com/playlist?list=".to_string();
    url.append(self.id);
    url
}

public fun youtube_music_track_url(self: &YouTubeMusicLink): String {
    let mut url = b"https://music.youtube.com/watch?v=".to_string();
    url.append(self.id);
    url
}

/// Builds the album URL, or — when `track_id` is set — the track URL with the
/// `?trackAsin=` selector.
public fun amazon_music_url(self: &AmazonMusicLink): String {
    let mut url = b"https://music.amazon.com/albums/".to_string();
    url.append(self.album_id);
    if (self.track_id.is_some()) {
        url.append(b"?trackAsin=".to_string());
        url.append(*self.track_id.borrow());
    };
    url
}

public fun tidal_album_url(self: &TidalLink): String {
    let mut url = b"https://tidal.com/browse/album/".to_string();
    url.append(self.id);
    url
}

public fun tidal_track_url(self: &TidalLink): String {
    let mut url = b"https://tidal.com/browse/track/".to_string();
    url.append(self.id);
    url
}

public fun deezer_album_url(self: &DeezerLink): String {
    let mut url = b"https://www.deezer.com/album/".to_string();
    url.append(self.id);
    url
}

public fun deezer_track_url(self: &DeezerLink): String {
    let mut url = b"https://www.deezer.com/track/".to_string();
    url.append(self.id);
    url
}

public fun soundcloud_set_url(self: &SoundCloudLink): String {
    let mut url = b"https://soundcloud.com/".to_string();
    url.append(self.user);
    url.append(b"/sets/".to_string());
    url.append(self.slug);
    url
}

public fun soundcloud_track_url(self: &SoundCloudLink): String {
    let mut url = b"https://soundcloud.com/".to_string();
    url.append(self.user);
    url.append(b"/".to_string());
    url.append(self.slug);
    url
}

public fun bandcamp_album_url(self: &BandcampLink): String {
    let mut url = b"https://".to_string();
    url.append(self.subdomain);
    url.append(b".bandcamp.com/album/".to_string());
    url.append(self.slug);
    url
}

public fun bandcamp_track_url(self: &BandcampLink): String {
    let mut url = b"https://".to_string();
    url.append(self.subdomain);
    url.append(b".bandcamp.com/track/".to_string());
    url.append(self.slug);
    url
}
