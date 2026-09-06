# Rinspace inner runtime integration

> Authority update (2026-09-06): private `rinspace` owns the product, outer UI, shared visual
> specification and integration contract. This fork owns the Mastodon inner-runtime implementation.
> The existing `@rinspace/world-shell` dependency and `config/rinspace-world-release.lock.json` are
> retired compatibility inputs awaiting replacement; no new release may be consumed from
> `rinspace-web`.

The Mastodon fork is the inner-world runtime for Mastodon-owned pages and services. It keeps native
status, timeline, search, notification, interaction, streaming and social-graph behavior, while its
Rinspace adapter implements the product contract recorded in the private repository.

The retirement audit found that `package.json` currently imports the vendored `0.1.8` shell
(`dddf517e44bd8df28accf1e56e027d73c285b2198f4e4b8f96b1c508a76cdafc`), while
`config/rinspace-world-release.lock.json` still records `0.1.4`
(`22fb42c996654a11a1fd28c9a173588b55e9de16ba9fe4da9ccf6ca7d9ed10d9`). The lock therefore
does not reproduce the current dependency and cannot be treated as release evidence. Do not repair
it by inventing public provenance; remove the package through the private-contract navigation
migration and create new release evidence from the resulting fork commit.

The inner navigation must match the current private outer-world navigation structure, control count,
geometry, typography, theme and responsive behavior. Its search, Explore, publish, notification,
theme, account and administration controls remain Mastodon adapters backed by real Mastodon state,
permissions, routes and APIs. The implementation must not reduce the outer navigation into a
synthetic shell or import new source from the retired public frontend.

The current navigation copy baseline is private `rinspace` commit `3aedfb63`.
The reviewed source SHA-256 values are `a9bc3a51…` (`SiteTopbarShell.tsx`),
`f841e127…` (`SiteTopbar.tsx`), `3ea68969…` (topbar adapter), and `8cb97368…`
(`topbar-shell.css`); the complete hashes and control matrix live in the private
`specs/rinspace-two-worlds/current-baseline.md`. Updating this adapter requires a
new explicit baseline and visual diff, never an automatic two-way sync.

Client navigation is normalized centrally. Except for permanent `/p/:id[/slug]` status links,
inner-world product documents use the canonical `world=inner` query. Service, asset, OAuth and
protocol routes retain their route-owned semantics. `yarn audit:rinspace-routes` enumerates
representative upstream routes and rejects legacy `/@handle/:statusId` generation.

The PWA starts and caches only `/?world=inner`. Its runtime cache accepts same-origin, allow-listed Mastodon assets and media; it does not cache outer `/` or cross-origin responses. Push notifications open `/p` for statuses and explicit inner URLs for dual account pages.

Anonymous protected HTML routes pass through `/auth/rinspace/recover`, which returns a public
inner-world shell with `rinspace_login=1` and carries the exact classified target in
`rinspace_return_to`. The React adapter opens the same phone-OTP dialog used by the outer product,
then submits that target through the server-side allowlist before OIDC. This avoids a protected-page
redirect loop while preserving the post-login destination. The Mastodon password page is not part
of the Rinspace login journey.

Rollback selects the previous verified Mastodon image and matching AGPL Corresponding Source together
with the compatible private Rinspace release. It must not reinstall or re-enable `rinspace-web` or
the retired public shell. Run the route audit and focused tests before selection, and never imitate a
code rollback by deleting database state.
