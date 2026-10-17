# Inactive browser parent-session recovery

The maintenance image uses `Dockerfile.rinspace-parent-recovery` and the exact
accepted Rinspace base image pinned there. Relative to base fork commit
`eecbc0f379bbf32f60fc6e77c96138485190e6c6`, only ApplicationController changes
runtime behavior. The accompanying controller regression spec verifies recovery
boundaries; dependencies, assets, migrations and Sidekiq remain unchanged.

Build from a clean checkout at the full reviewed commit, passing it as
`--build-arg SOURCE_COMMIT=<full commit>`. The private Rinspace product repository
owns compatibility verification, immutable image/source/SBOM/provenance binding,
and the protected Web-only rollout. Do not deploy a working-tree file into a live
container or republish the upstream Mastodon registries.

For HTML GET with a confirmed inactive parent, discard only this browser's inner
login and use the existing safe-return login recovery entry. Do not call normal
logout callbacks (they revoke the central parent). JSON, XHR and unsafe methods
remain 401 without replay; Identity unavailable remains 503 and retains the
credentials. A local recovery must not clear main-site cookies, editor storage,
other devices, or another user's sessions.

Distribute the complete matching AGPL Corresponding Source, including this
recipe, with each image. The immutable base, new full source commit, controller
hash and rollback image are recorded in the release evidence. Normal active
sessions and existing content APIs must be checked after rollout.
