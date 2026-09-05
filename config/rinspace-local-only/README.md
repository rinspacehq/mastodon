# Deploying strict local-only mode

These files are defense-in-depth examples, not an instruction to deploy. Production changes still require an approved stack release and a separate execution decision.

1. Include `nginx-http.conf` in the nginx `http` block and `nginx-server.conf` before every Mastodon proxy location. Run `nginx -t` before reload.
2. Apply `network-policy.yaml` only after its namespace, selectors and ports match the actual immutable deployment. It intentionally has no public internet egress.
3. Route each approved non-federation integration (object storage, mail, web push, moderation or translation) through `rinspace-egress-proxy:8443`. The proxy must use an explicit destination allow-list and deny ActivityPub, WebFinger and NodeInfo paths and media types.
4. Keep `RINSPACE_LOCAL_ONLY=true`. Setting it to false outside the test environment aborts application boot.
5. Run `bundle exec rake rinspace:local_only:audit` before opening traffic and on every release. A non-zero result blocks release.

An emergency rollback restores the previous immutable Rinspace fork image and its matching database/schema release. Do not roll back only the edge or only the application gate; that creates an unprotected federation path.
