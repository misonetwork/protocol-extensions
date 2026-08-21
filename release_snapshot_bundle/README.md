# `release_snapshot_bundle`

> The write-once on-chain pointer from a Miso release to its snapshot bundle — the Walrus quilt of curated bonus material a buyer gets access to.

**Attaches to:** `Release` (Miso core) as a dynamic field on its `&mut UID`, reached through the release's cap-gated `uid_mut`.

A snapshot bundle is one Walrus quilt, and the quilt is self-describing: a plaintext `manifest.json` patch carries all the metadata, media patches are chunk-encrypted under one AES envelope key, and that key travels Seal-wrapped inside the quilt as its `key.seal` patch. This package stores none of that — no ciphertext, no metadata, no access policy (unlocking by holding a Record is `miso_record_acl`'s concern, in miso-record-extensions). The stored value is the quilt's `ori::WalrusData` blob reference, and nothing else.

**The slot is write-once.** `set_snapshot_bundle` aborts if a bundle is already set, and there is no unset, no remove, and no replace function. That absence is a product guarantee: the bundle a buyer's Record points at can never be swapped out from under them. More content later means a new Release.

## Entry points

- **`release_snapshot_bundle::set_snapshot_bundle`** — cap-gated; sets the release's bundle reference, once. Aborts with `EBundleAlreadySet` if already set; rejects quilt-patch references (the bundle is a whole quilt blob, not a slice of one) and encrypted outer references (the outer quilt blob is plaintext by design — the manifest must be readable; encryption is per-patch inside). Emits `SnapshotBundleSetEvent` carrying the reference — with no later mutation possible, that one event is the slot's complete history.
- **`release_snapshot_bundle::has_snapshot_bundle`** — permissionless; whether a bundle is set.
- **`release_snapshot_bundle::snapshot_bundle`** — permissionless; the bundle reference. Aborts with `ENoSnapshotBundle` if none is set.

## Dependencies

- [`miso`](https://github.com/misonetwork/protocol) — `Release` / `ReleaseAdminCap` and the cap-gated `uid_mut` extension surface.
- [`ori`](https://github.com/unconfirmedlabs/ori) — the `WalrusData` reference type.
