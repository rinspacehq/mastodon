# Community governance, recommendations and view counts

This document is an engineering and operations contract for Rinspace's local-only inner world. It does not enable production traffic.

## Governed writes

Every authenticated non-read REST request passes the verified Rinspace identity gate in `Api::BaseController`, including third-party OAuth clients. Status creation and edits review the content warning, body and poll choices through the server-to-server moderation client before persistence. Replies and quotes use the same status path. Media create/update reviews user-authored descriptions before persistence; Mastodon's normal MIME, size and processing controls still apply to the binary. Identity-owned display name, biography, avatar, header, descriptions and profile fields cannot be edited through Mastodon and must arrive through the signed Control Plane projection.

The moderation request uses a purpose-specific HMAC key, short timeout, timestamp, nonce and request digest. `pass` is the only accepting response. `review`, `block`, malformed responses, missing configuration and outages fail closed. Mastodon's native rate limits, blocks, mutes, reports, appeals, moderation notes, account actions and admin audit log remain authoritative. Operators preserve only the case evidence required by the retention schedule and access it by role.

## Visibility matrix

| Visibility | Direct read | Search | Shared recommendation candidate | View count returned | Share |
| --- | --- | --- | --- | --- | --- |
| Public | Anyone allowed by normal account/status policy | Local search when approved | Yes, only local + approved + discoverable + available | Yes | Public link |
| Unlisted | Anyone with the link, subject to policy | No broad discovery | No | Yes | Link only |
| Followers-only | Authorized followers and mentioned participants | No broad discovery | No | Only to an authorized reader | No public share |
| Direct | Mentioned participants only | No | No | Never serialized or counted | No |

Removed, unreviewed, rejected, remote, unavailable-account, blocked and muted content is excluded. Gorse receives candidate identifiers and minimized interaction signals; it never decides authorization. Mastodon re-applies visibility, moderation, account, block and mute filters after ranking. Empty, cold-start, anonymous and unavailable-Gorse requests fall back to a filtered recent local list.

## Recommendation controls and data lifecycle

The inner home defaults to **Recommended**, with a separate chronological **Following** feed. The selection is stored per Rinspace account. Disabling personalization removes access to the personalized feed, switches to Following and stops like, repost, reply, bookmark, follow and eligible-read feedback. Users can inspect/delete explicit interest tags and clear the complete Gorse profile. The browser never sees the Gorse endpoint or API key.

Purpose and default retention:

- Redis view dedupe HMAC: abuse-resistant aggregate counting, five minutes, then automatic expiry.
- Gorse interaction feedback: ranking the local feed, 30 days; removal/undo deletes matching feedback where supported, and profile clearing deletes the user profile.
- Derived recommendation profile: no more than 180 days after last use, or immediately on user clearing/account deletion.
- Aggregate status view count: retained with the status and removed with normal status lifecycle; no viewer ID, IP, session or per-view event table is persisted.
- Moderation and appeal evidence: retained under the separately approved community/legal schedule, with role access and deletion holds documented per case.

Operations must configure Gorse TTL/compaction to these maxima and verify deletion jobs before enabling recommendations. Longer retention requires a new documented purpose and review; analytics convenience is not sufficient.

## View-count semantics

The product label is “浏览次数”/“views”, never “unique visitors”. An authenticated local reader sends a count only after a visible card is at least 50% intersecting for one second; detail pages use the same tracked status element and one-second rule. SSR, prefetch/preview, bot-like agents, embeds and health checks do not count. A five-minute HMAC of stable subject, status and ephemeral browser session suppresses technical duplicates in Redis. Sidekiq performs one atomic aggregate increment and stores no viewer event.

Public and unlisted status counts may be shown. Followers-only counts appear only after normal read authorization. Direct messages neither increment nor serialize a count. The count signal and Gorse read feedback are independent: counting may continue when personalization is off, but recommendation feedback must not.

## Failure, alerts and rollback

Alert on moderation rejection/unavailability rates, review backlog age, identity-gate denials, Gorse latency/error/empty-result rate, filtered-candidate ratio, feedback deletion failure, Redis dedupe errors, view-worker retries and count jumps. A recommendation outage falls back to filtered recent content; a moderation outage closes governed content writes; a view-count outage may drop counts but must not block reading.

Rollback disables recommendation and view-write feature flags first, drains or discards only idempotent jobs, restores the previous verified application artifact, and uses forward database repair. Additive columns may remain unused. Never expose unfiltered Gorse output, re-enable a second identity source or delete aggregate rows to imitate a code rollback.
