# Rinspace fork patch inventory

[简体中文](./PATCHES.zh-CN.md)

This document is the upgrade boundary between upstream Mastodon and the public Rinspace fork. It does not authorize federation or production deployment. Rinspace phase one remains local-only, and every behavior change must be reviewable as an explicit patch rather than an unrecorded server edit.

## Baseline

| Field | Value |
| --- | --- |
| Fork repository | `rinspacehq/mastodon` |
| Upstream repository | `mastodon/mastodon` |
| Fork commit | `0a32b4a831838ef1f363a915c2e71e2a1b52cf0d` |
| Upstream `main` at inspection | `0a32b4a831838ef1f363a915c2e71e2a1b52cf0d` |
| Describe | `v4.7.0-beta.1-180-g0a32b4a83` |
| Rinspace logical patch count | `10` (working tree; not a release) |
| Recorded | `2026-09-05` |

These IDs describe reviewable logical patches while implementation remains uncommitted. A release must replace the working-tree marker with immutable commit IDs and must not publish a dirty tree.

## Patch categories

- `upstreamable`: a generally useful fix or improvement suitable for an upstream Mastodon pull request.
- `rinspace-product`: behavior specific to the Rinspace two-world product, such as the shared shell or `/p/:id/:slug` Web route.
- `long-lived-safety`: a boundary that must survive upstream upgrades, such as strict local-only federation controls.

## Inventory

| ID | Category | Upstream base | Changed areas | Verification | License/API impact | Upgrade notes |
| --- | --- | --- | --- | --- | --- | --- |
| `RIN-001` | `long-lived-safety` | `0a32b4a831838ef1f363a915c2e71e2a1b52cf0d` | Local-only Rack/Sidekiq guards, fetch/search/feed/API boundaries, edge and egress policy, audit task | Focused local-only RSpec; `rails rinspace:local_only:audit` before release | No public API expansion; operators must publish this AGPL fork source | Re-audit every new resolver, federation route, worker, FASP integration and outbound request path |
| `RIN-002` | `rinspace-product` | same | `/p/:id/:slug`, slug v1, REST/Web metadata and client links; legacy status routes return 404 | Ruby/TypeScript shared fixtures, request specs, route audit | Public Web URL changes; ActivityPub identifiers stay unchanged | Recheck status, quote, notification, search, share and oEmbed generators after rebase |
| `RIN-003` | `rinspace-product` | same | Exact `world-shell` artifact, shared topbar, inner layout and adapter; Rinspace mark and localized wordmark use the outer-world navigation geometry | `yarn typecheck`, production Vite build, lock checksum verification | Bundled AGPL-compatible public package; source manifest retained | Reinstall an immutable clean artifact; preserve the two independent brand controls and compare both runtimes visually |
| `RIN-004` | `long-lived-safety` | same | Client route canonicalization, route inventory, PWA start URL, Service Worker cache and push targets | `yarn audit:rinspace-routes`; focused Vitest Service Worker and path suites | PWA navigation/cache behavior changes | New upstream routes fail the explicit audit until added to the public route contract |
| `RIN-005` | `long-lived-safety` | same | Pre-provisioned OIDC identity, signed identity/tag/follow APIs, profile and handle lifecycle, exact-host HTTPS avatar/header import with optional-update and explicit-clear semantics | Focused binding, service-request, OIDC and service specs | New private integration API and `RINSPACE_PROFILE_MEDIA_HOSTS`; keys remain server-only | Preserve fail-closed collision, terminal deletion and absent-header compatibility semantics; do not broaden the media allowlist into federation egress |
| `RIN-006` | `long-lived-safety` | same | Global governed-write identity gate and Control Plane moderation | Governed-write request and moderation-client specs | Mutation behavior and moderation dependency | Re-enumerate every upstream mutation controller after rebase |
| `RIN-007` | `rinspace-product` | same | Local Gorse candidates, post-filtered recommendation service, feedback and user controls, discoverability backfill and filtered recent fallback for cold-start discovery | Gorse, recommendation, trends and preference specs | New local preference/timeline APIs | Gorse ranks only; authorization stays in Mastodon; explicit discoverability opt-outs are never overwritten |
| `RIN-008` | `rinspace-product` | same | Aggregate `views_count`, Redis HMAC dedupe, visibility-aware serialization and client observation | Request, worker and TypeScript checks | Adds optional REST Status field and one local write endpoint | Keep counting distinct from recommendation feedback |
| `RIN-009` | `long-lived-safety` | same | Additive status review/view database migrations and validation | Isolated PostgreSQL migration plus focused Rails suite | Database schema expansion | Contract only after observation; production recovery is forward-only |
| `RIN-010` | `long-lived-safety` | same | Independent rollout gates for authenticated mutations, recommendations and view counting | Request specs with each gate disabled; non-test defaults inspected | Adds operator environment flags; defaults fail closed | A new image never enables a stage; keep flags false until signed rollout evidence exists |

## Upgrade checklist

1. Fetch the upstream repository and record the old fork commit, old upstream base, proposed upstream commit, Ruby/Node/package-manager versions, PostgreSQL and Redis support, and container tags or digests.
2. Create a dedicated upgrade branch. Never rebase or force-update a deployed release tag.
3. Reapply inventory entries in ID order. For each conflict, preserve the documented invariant or stop and redesign the patch; do not silently accept either side.
4. Re-enumerate Rails, React Router, API, OAuth, streaming, media, ActivityPub, WebFinger, NodeInfo, Sidekiq delivery, and service-worker routes against the versioned Rinspace world-route contract.
5. Prove strict local-only mode at the edge, application, worker, and network-egress layers. A newly introduced remote resolver, inbox, delivery path, or background job blocks the upgrade until classified and disabled.
6. Run the smallest checks for each patch, then the relevant Mastodon Ruby, JavaScript, accessibility, migration, and production-asset suites. Record exact commands and results in the change.
7. Review every REST/entity/type change and update public API documentation or Rinspace contract fixtures as required.
8. Review AGPL source availability, copied material, dependency licenses, database migration reversibility, and operator-facing configuration changes.
9. Build immutable images and source artifacts, record their digests with the exact fork commit and consumed `@rinspace/world-shell`/world-route versions, and rehearse rollback before release approval.

## Non-negotiable invariants

- Browser status URLs are `/p/:id` and `/p/:id/:slug`; upstream `/@username/:statusId` and `/embed` variants return `404` and do not redirect.
- Local identity binding uses the stable Rinspace subject. Handle collisions fail closed and must not create suffixed accounts.
- Mastodon remains the single source of truth for the local social follow graph.
- Federation code may remain in the source tree, but phase-one ingress, egress, discovery, remote resolution, delivery, and remote presentation stay disabled and observable.
- The fork consumes exact public contract artifacts. It does not copy an unversioned Rinspace frontend worktree or use a floating branch/tag in a release.
