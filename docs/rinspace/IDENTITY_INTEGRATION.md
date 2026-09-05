# Rinspace identity integration

This fork accepts local identities only after the private Rinspace Control Plane has pre-provisioned them through the signed `/api/rinspace/v1` service endpoints. OIDC login never creates an account, reattaches by e-mail, or appends a suffix to a conflicting handle.

Required production settings are documented in `.env.production.sample`. `RINSPACE_IDENTITY_STRICT=true`, OIDC discovery, PKCE, nonce, one-click SSO, and OmniAuth-only login are boot-time invariants. The OIDC client secret and Control Plane HMAC key must be separate.

The immutable OIDC `sub` is stored in both `Identity.uid` and `RinspaceIdentityBinding.subject`. A profile rename updates the same local `Account`; the old handle is not redirected or reserved. Disabled bindings cannot log in. Deleted bindings are terminal and retain only the minimum evidence needed to prevent accidental duplicate identities.

Control Plane service calls use an HMAC over method, request URI, timestamp, nonce, optional key ID, and SHA-256 body hash. Requests outside the two-minute window and nonce replays are rejected. Private keys must never be exposed to browser code.

Tag bindings are explicit and versioned. A same-name hashtag does not create a Rinspace knowledge tag. Follow imports call Mastodon's normal `FollowService` and therefore preserve locked-account follow requests, blocks, limits, notifications, and normal relationship rules. Integration idempotency records make a repeated command safe; a key reused for different content is rejected.

Database rollback uses the migration's normal down path only before any production data exists. Once bindings or relationships have been written, recovery is forward-only: stop writes, reconcile by stable subject/tag ID, unbind tags explicitly, or restore the previous read route. Never delete bindings merely to make a conflicting login succeed.
