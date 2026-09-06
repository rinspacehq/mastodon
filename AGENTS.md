# Rinspace Mastodon fork instructions

These instructions apply to this Rinspace Mastodon fork and supplement `/home/ubuntu/AGENTS.md`.

## Authority boundary

- This fork is canonically `rinspacehq/mastodon`. `origin` must fetch and push only to that
  repository. `lunifans` is the maintainer's personal identity, not an alternative repository
  owner or release namespace.
- The official `mastodon/mastodon` remote is fetch-only `upstream`; pushing to it is prohibited.
- `/home/ubuntu/rinspace` is the private Rinspace product repository and the authority for product
  requirements, outer-world UI, shared visual behavior, integration contracts, deployment and
  operations.
- This fork is a secondary implementation repository. It owns only behavior that belongs inside the
  Mastodon inner runtime: statuses, timelines, search, notifications, interactions, local social
  graph, streaming, Mastodon-rendered pages and their Rinspace adapters.
- `/home/ubuntu/rinspace-web` and `@rinspace/world-shell` are retired experiment inputs. Do not
  install a new public-frontend release, regenerate contracts from that repository, or use its UI as
  the visual reference for new work.
- Mastodon remains the data authority for its local statuses, interactions, notifications and social
  follow graph. That data ownership does not make the fork the authority for the overall Rinspace
  product or outer-world design.

## Working rules

- Work through a named worktree under `/home/ubuntu/.worktrees/`; record its branch, exact commit and
  dirty state before changing files.
- Preserve unrelated and untracked work. In particular, never delete an existing experimental
  directory merely to make the tree clean.
- Begin cross-runtime behavior with a contract or specification in private `rinspace`. Implement
  only the Mastodon-owned adapter here and bind every control to real Mastodon state, permissions,
  routes and APIs.
- Match navigation and theme against the current private `rinspace/ui` implementation and approved
  specification. Do not invent a reduced shell or treat a synthetic demo as production truth.
- For third-party components such as Animate UI, inspect the official upstream and exact pinned
  revision first. Use only the subset and adaptation boundary approved in private `rinspace`; do not
  infer the library from `rinspace-web`.
- Preserve upstream Mastodon semantics and accessibility unless a private Rinspace requirement
  explicitly changes them. Keep federation disabled and observable under the current local-only
  product phase.

Do not commit, push, publish, release or deploy without explicit authorization. Validate focused
Ruby/TypeScript behavior serially and report commands honestly; do not run a broad production build
for documentation-only maintenance.
