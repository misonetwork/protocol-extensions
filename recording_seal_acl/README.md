# `recording_seal_acl`

> Seal decryption policy for a recording's encrypted masters: rights-holder-granted principals — raw addresses or SuiNS names — may fetch the master's data-encryption key.

**Attaches to:** `Recording` (Miso core). Grants are dynamic fields on the recording's UID, written through the cap-gated `uid_mut` and managed by the [`meigi`](https://github.com/unconfirmedlabs/meigi) primitive under this package's `Witness` scope.

An encrypted master's AES data-encryption key (the Seal-sealed `dek` inside the master's `walrus_data`) is sealed under **this package's namespace** with identity `[recording_id ‖ pcm_digest]`. Seal key servers release the key by dry-running the `seal_approve*` entry points, which check that the requester is a granted principal:

- **Address grants** authorize exactly that address.
- **Name grants** (e.g. `delivery.miso.sui`) authorize whatever address the SuiNS name currently targets, pinned to the name's registration NFT. The granted service rotates keys freely by re-pointing its name; a lapsed-and-re-registered name presents a different registration NFT and fails closed.

Granting and revoking require the `RecordingAdminCap` — every grant is the rights holder's explicit, revocable, on-chain consent (revocation is prospective; true revocation of already-released keys is re-encryption, which `recording_master`'s remove/add under the same digest supports).

This package is deliberately tiny and separate from `recording_master`: Seal binds every sealed DEK to the policy package's original ID forever at encryption time, so the policy must be a small, stable, upgradeable package. It does not check that a master is attached under the identity's digest — the sealed DEK only decrypts the blob it was produced for, so attachment adds nothing and the policy stays free of any master-type dependency.

## Entry points

- **`acl::grant_address` / `acl::revoke_address`** — Grants/revokes a raw address, gated by the `RecordingAdminCap`.
- **`acl::grant_name` / `acl::revoke_name`** — Grants/revokes a SuiNS name (takes `&SuiNS`; the current registration NFT id is pinned automatically at grant time).
- **`acl::seal_approve`** *(entry)* — Key-server dry-run for a directly granted address. Verifies the identity is bound to this recording and the sender holds a grant.
- **`acl::seal_approve_name`** *(entry)* — Key-server dry-run for a name grant. The requester passes the name they claim; verifies the grant exists, the pin matches the name's current registration, and the name targets the sender.

## Views

- **`acl::scope`** — The meigi scope (`Witness` defining `TypeName`) this policy stores grants under.
- **`acl::is_address_authorized` / `acl::is_name_authorized`** — Non-aborting authorization checks for clients.

## Dependencies

- **`miso`** — core protocol; provides `Recording`, `RecordingAdminCap`, and the cap-gated `uid_mut`.
- **`meigi`** — grant storage and verification (witness-scoped principals on a `UID`, SuiNS resolution + registration pinning).
- **`suins`** (`@suins/core` via MVR) — name resolution in `grant_name` / `seal_approve_name`.

## Build & test

```sh
sui move build
sui move test
```
