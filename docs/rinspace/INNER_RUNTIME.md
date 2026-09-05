# Rinspace inner runtime integration

The Mastodon fork is the path-owned inner-world runtime. It consumes an exact `@rinspace/world-shell` tarball recorded by `config/rinspace-world-release.lock.json`; the dirty development lock in this working tree is intentionally not releasable.

The shared topbar is rendered once above Mastodon's runtime. Mastodon's desktop navigation panel, central feed and discovery area remain product navigation, and its mobile navigation remains the bottom bar. Duplicate Mastodon brand headers are removed. The `Rinspace` wordmark returns to the current inner home; the logo uses the public route contract to flip a dual resource or return to the opposite home for path-owned pages.

Client navigation is normalized centrally. Dual resources receive `world=inner`; inner-only pages such as `/p/:id`, lists and notification details stay path-owned. `yarn audit:rinspace-routes` enumerates representative upstream routes and rejects legacy `/@handle/:statusId` generation.

The PWA starts and caches only `/?world=inner`. Its runtime cache accepts same-origin, allow-listed Mastodon assets and media; it does not cache outer `/` or cross-origin responses. Push notifications open `/p` for statuses and explicit inner URLs for dual account pages.

Rollback is code-only before any production switch: restore the four logical patches in `PATCHES.md` together, reinstall the previous clean world release, run the route audit and focused tests, rebuild assets, and only then select the previous immutable stack release. Do not roll back database state by deleting data.
