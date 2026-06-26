# `recording_master`

> Generic, media-agnostic extension for attaching ingester-produced "master" values to a Miso recording, namespaced by the ingester witness and a content digest.

**Attaches to:** `Recording` (Miso core) as dynamic fields on its `&mut UID`, reached through the recording's cap-gated `uid_mut`. The module never references a concrete master type, so it blesses no specific ingester. Attachment is via Sui dynamic fields keyed by `MasterKey { ingester, content_digest }`.

A "master" is any value with `store` (e.g. Miso's `audio::Audio`, or a future video/immersive type). Each master is stored under a `MasterKey` whose `ingester` component is the defining `TypeName` of an ingester witness `W`, derived inside `add` from the witness itself — so only a package that can produce `W` can write under `W`'s namespace. The `content_digest` (e.g. a PCM digest) discriminates multiple masters from the same ingester and is a stable, storage-independent handle that survives re-keying / re-encoding.

The design is doubly gated: writing requires the rights holder's authority (the `RecordingAdminCap`, which yields `uid_mut`), and writing a given namespace requires the ingester witness. Trust is a key lookup, not a registry — a consumer reads masters from the ingester type(s) it trusts and ignores the rest. Detaching and reads require only the recording, since removing or inspecting a value cannot forge namespace trust.

The extension operates on `Recording` directly rather than a bare `&mut UID`: a `&mut UID` cannot be returned from a Move call and so cannot be threaded through a PTB, so every Miso extension takes the typed core object plus its admin cap.

## Entry points

- **`master::add<RecordingShare, CompositionShare, W: drop, M: store>`** — Attaches `master` under ingester `W`'s namespace, discriminated by `content_digest`. The witness `W` proves ingester authority (its defining `TypeName` becomes the key's `ingester`); the `RecordingAdminCap` carries the rights holder's authority. Aborts if a master is already present under the exact `(ingester, content_digest)`.
- **`master::remove<RecordingShare, CompositionShare, M: store>`** — Detaches and returns the master stored under `(ingester, content_digest)`. Gated only by the `RecordingAdminCap` (no witness needed); `M` must match the stored value's type. Supports key rotation: remove an old encrypted master and add a freshly re-keyed one under the same digest.

## Views

- **`master::borrow<RecordingShare, CompositionShare, M: store>`** — Borrows the master attached under `(ingester, content_digest)`.
- **`master::exists_`** — Returns whether a master is attached under `(ingester, content_digest)`.
- **`master::new_key`** — Builds a `MasterKey` from `(ingester, content_digest)`, e.g. for clients computing the dynamic-field id.
- **`master::key_ingester`** — Returns the ingester `TypeName` of a `MasterKey`.
- **`master::key_content_digest`** — Returns the `content_digest` of a `MasterKey`.

## Dependencies

- **`miso`** — core protocol; provides `Recording` and its `RecordingAdminCap` + `uid_mut`/`uid` accessors. The module remains media-agnostic — it depends on core only to reach the recording, never on any concrete master type; trust in *what* is attached is carried by the ingester witness rather than by a package dependency.

## Build & test

```sh
sui move build
sui move test
```
