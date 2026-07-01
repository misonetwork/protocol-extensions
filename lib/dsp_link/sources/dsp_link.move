// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// `DspLink<Data>` — a typed link to a release on a single Digital Service
/// Provider (DSP): Spotify, Apple Music, Amazon Music, Tidal, Deezer, etc.
///
/// This is the low-level primitive behind the streaming-links extension. It is
/// deliberately tiny and protocol-agnostic: it knows nothing about any specific
/// DSP, nor about `miso::release` — it is just a generic wrapper around a
/// `Data` payload plus the machinery to store exactly one such link, by type,
/// as a dynamic field on any object's `UID`.
///
/// `Data` is the DSP-specific native identifier(s) — e.g. a Spotify album id, or
/// Apple Music's `(storefront, album_id, track_id)`. Each DSP defines its own
/// `Data` type in its own small package (`dsp_link_spotify`,
/// `dsp_link_apple_music`, …), so adding a DSP is a new package, never a change
/// here. URLs are never stored: a client rebuilds the public URL from the `Data`
/// it reads back, so a DSP reshaping its URLs needs no on-chain change.
///
/// Storage is keyed by `DspLinkKey<Data>`, whose `phantom Data` makes
/// `DspLinkKey<SpotifyData>` and `DspLinkKey<AppleMusicData>` distinct keys — so
/// each DSP occupies its own independent field on the same `UID`, and a new DSP
/// can be added to a record without touching the others.
module dsp_link::dsp_link;

use sui::dynamic_field as df;

// === Errors ===

/// No `DspLink<Data>` is stored under this `UID`.
const ENoLink: u64 = 0;

// === Types ===

/// A link to a release on one DSP. `Data` carries that DSP's native
/// identifier(s); the public URL is rebuilt from it client-side.
public struct DspLink<Data: copy + drop + store> has copy, drop, store {
    data: Data,
}

/// Dynamic-field key for the single `DspLink<Data>` on a `UID`. The
/// `phantom Data` gives each DSP its own field.
public struct DspLinkKey<phantom Data>() has copy, drop, store;

// === Constructor / accessor ===

/// Wraps a DSP-specific payload into a link.
public fun new<Data: copy + drop + store>(data: Data): DspLink<Data> {
    DspLink { data }
}

/// The wrapped DSP-specific payload.
public fun data<Data: copy + drop + store>(self: &DspLink<Data>): Data {
    self.data
}

// === UID storage ===
//
// Exactly one `DspLink<Data>` per `Data` type per `UID`, keyed by
// `DspLinkKey<Data>`. Callers pass the object's `UID` (e.g. a release's, via its
// admin cap), keeping this module free of any object-specific dependency.

/// Whether a `DspLink<Data>` is stored under `uid`.
public fun exists_<Data: copy + drop + store>(uid: &UID): bool {
    df::exists(uid, DspLinkKey<Data>())
}

/// Sets the `DspLink<Data>` under `uid`, replacing any existing one.
public fun set<Data: copy + drop + store>(uid: &mut UID, link: DspLink<Data>) {
    if (df::exists(uid, DspLinkKey<Data>())) {
        *df::borrow_mut(uid, DspLinkKey<Data>()) = link;
    } else {
        df::add(uid, DspLinkKey<Data>(), link);
    }
}

/// The stored `DspLink<Data>`, or `none` if absent.
public fun get<Data: copy + drop + store>(uid: &UID): Option<DspLink<Data>> {
    if (df::exists(uid, DspLinkKey<Data>())) {
        option::some(*df::borrow(uid, DspLinkKey<Data>()))
    } else {
        option::none()
    }
}

/// Borrows the stored link. Aborts if none is stored.
public fun borrow<Data: copy + drop + store>(uid: &UID): &DspLink<Data> {
    assert!(df::exists(uid, DspLinkKey<Data>()), ENoLink);
    df::borrow(uid, DspLinkKey<Data>())
}

/// Mutably borrows the stored link. Aborts if none is stored.
public fun borrow_mut<Data: copy + drop + store>(uid: &mut UID): &mut DspLink<Data> {
    assert!(df::exists(uid, DspLinkKey<Data>()), ENoLink);
    df::borrow_mut(uid, DspLinkKey<Data>())
}

/// Removes and returns the stored link. Aborts if none is stored.
public fun remove<Data: copy + drop + store>(uid: &mut UID): DspLink<Data> {
    assert!(df::exists(uid, DspLinkKey<Data>()), ENoLink);
    df::remove(uid, DspLinkKey<Data>())
}

/// Removes the stored link if present, discarding it. No-op if absent.
public fun clear<Data: copy + drop + store>(uid: &mut UID) {
    if (df::exists(uid, DspLinkKey<Data>())) {
        let _: DspLink<Data> = df::remove(uid, DspLinkKey<Data>());
    }
}
