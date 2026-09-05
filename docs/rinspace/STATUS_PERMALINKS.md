# Rinspace status permalinks

The only browser status URL family is `/p/:id/:slug`, with `/p/:id` as a short normalization entry. The numeric Mastodon status ID is the sole lookup key. A missing, stale or incorrect slug receives a temporary `302` to the current canonical URL; no historical slug table exists.

`rinspace-status-slug-v1` is published by the versioned Rinspace world release. It normalizes visible text with Unicode NFKC, removes HTML, URLs, email addresses, mentions and control characters, keeps Unicode letters/marks/numbers, folds other runs to `-`, lowercases, and truncates at 48 grapheme clusters. Sensitive, followers-only, direct, empty and media-only posts use `post`. Content warnings and media filenames are never inputs.

Replies and quote posts use their own status ID. A quoted status retains its own permalink. A boost/repost wrapper has no public permalink: a request by the wrapper ID redirects to the original status. Polls and media stay subordinate to the owning status. Lists, notifications and conversations retain authorized internal identifiers and do not gain public slugs. Deleted, unavailable or unauthorized status IDs return the normal `404`/authorization outcome.

ActivityPub actor, status, activity, replies, likes and shares URIs are intentionally unchanged. They are protocol identities, not browser canonical URLs, and strict local-only mode blocks them at the public edge.

The public TypeScript generator and Ruby generator are verified against the same `status-slug-v1.json` fixture. Upgrade the algorithm only under a new version and ship the fixture in the immutable world release.
