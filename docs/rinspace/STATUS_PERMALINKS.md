# Rinspace status permalinks

The only browser status URL family is `/p/:id/:slug`, with `/p/:id` as a short normalization entry. The numeric Mastodon status ID is the sole lookup key. A missing, stale or incorrect slug receives a temporary `302` to the current canonical URL; no historical slug table exists.

`rinspace-status-slug-v1` is owned by the versioned contract in the private Rinspace product repository. It normalizes visible text with Unicode NFKC, removes HTML, URLs, email addresses, mentions and control characters, keeps Unicode letters/marks/numbers, folds other runs to `-`, lowercases, and truncates at 48 grapheme clusters. Sensitive, followers-only, direct, empty and media-only posts use `post`. Content warnings and media filenames are never inputs.

Replies and quote posts use their own status ID. A quoted status retains its own permalink. A boost/repost wrapper has no public permalink: a request by the wrapper ID redirects to the original status. Polls and media stay subordinate to the owning status. Lists, notifications and conversations retain authorized internal identifiers and do not gain public slugs. Deleted, unavailable or unauthorized status IDs return the normal `404`/authorization outcome.

ActivityPub actor, status, activity, replies, likes and shares URIs are intentionally unchanged. They are protocol identities, not browser canonical URLs, and strict local-only mode blocks them at the public edge.

The Mastodon Ruby generator and the private Rinspace consumer must be verified against the same versioned fixture. The currently vendored fixture from the retired public release is compatibility evidence only; before changing the algorithm, move its canonical source to private `rinspace`, assign a new version and ship the matching fixture with the immutable Mastodon source release.
