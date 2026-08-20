# `release_registry`

> The recommended canonical parent namespace for deriving Miso release ids — shared, permissionless, and undeletable.

**Attaches to:** nothing. Unlike most extensions, this package stores no data on any core object's UID; it *is* an object — a `ReleaseRegistry` whose own `UID` serves as the derivation parent that `miso::release::new` claims release ids from.

Core is parent-agnostic: `release::new` takes `parent: &mut UID` and commits every release id to the `(parent, digest)` pair. This package supplies the one recommended parent and deliberately nothing else — it neither gates who may assemble a release through it nor interprets what a `Track` means. Consent lives in the `Track`s themselves (each minted by its recording's admin via cap-gated `miso::track::new`); assembly through the registry is bookkeeping over consent already given.

The module exposes **no delete function and no `uid_mut`**. That is a consent guarantee, not an omission: a track's `target_release_id` commits to its namespace's liveness, and a deletable parent would strand every track and offer that ever targeted it. Keeping the surface to exactly one capability — being a derivation parent — is what makes the guarantee durable.

The module exposes no constructor: the only `ReleaseRegistry` that can ever exist is the canonical one created and shared at package initialization, so "the registry" is unambiguous on-chain. Throughput serializes through it (every `new_release` takes `&mut` on the shared object); the ceiling is accepted — releases are rare events. Alternative namespaces live in other packages: core is parent-agnostic, and any object exposing a `&mut UID` (a release escrow, for instance) can parent its own releases, with ids under different parents never colliding.

## Entry points

- **`release_registry::new_release`** — permissionless; assembles a release through this registry by delegating to `miso::release::new` with the registry as parent, returning the `(Release, ReleaseAdminCap)` pair for the caller to publish and route.
- **`release_registry::derive_target_release_id`** — view; the id `new_release` would produce for the given digest inputs under this registry, without creating anything.
- **`release_registry::id`** — the registry's object id, the derivation parent both functions above commit to.

The canonical instance is created and shared by package initialization, which emits `ReleaseRegistryCreatedEvent` so clients can discover its id from the publish transaction.
