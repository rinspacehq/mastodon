const WORLD_PARAMETER = 'world';
const INNER_WORLD = 'inner';
const SERVICE_PREFIXES = [
  '/api',
  '/auth',
  '/oauth',
  '/system',
  '/packs',
  '/assets',
  '/streaming',
  '/.well-known',
];
const INNER_PRODUCT_PATH =
  /^\/(?:$|home(?:\/|$)|timelines(?:\/|$)|deck(?:\/|$)|getting-started(?:\/|$)|conversations(?:\/|$)|public(?:\/|$)|tags(?:\/|$)|lists(?:\/|$)|notifications(?:\/|$)|favourites(?:\/|$)|bookmarks(?:\/|$)|pinned(?:\/|$)|directory(?:\/|$)|explore(?:\/|$)|publish(?:\/|$)|profile(?:\/|$)|@[A-Za-z0-9_@.-]+(?:\/|$)|accounts(?:\/|$)|collections(?:\/|$)|statuses(?:\/|$)|follow_requests(?:\/|$)|blocks(?:\/|$)|domain_blocks(?:\/|$)|followed_tags(?:\/|$)|mutes(?:\/|$)|settings(?:\/|$)|filters(?:\/|$)|invites(?:\/|$)|admin(?:\/|$)|about(?:\/|$)|search(?:\/|$)|web(?:\/|$)|media(?:\/|$)|polls(?:\/|$)|links(?:\/|$)|keyboard-shortcuts(?:\/|$)|overview(?:\/|$)|relationships(?:\/|$)|severed_relationships(?:\/|$)|statuses_cleanup(?:\/|$)|privacy-policy(?:\/|$)|terms(?:\/|$)|terms-of-service(?:\/|$)|start(?:\/|$))/;

/**
 * Canonicalize a Mastodon-side navigation without guessing route ownership.
 * Every Mastodon product page gains an explicit world selector except for the
 * stable `/p/:id[/slug]` permalink family. Service URLs remain untouched.
 */
export function innerWorldPath(value: string) {
  const url = new URL(value, window.location.origin);
  if (url.origin !== window.location.origin) return value;
  if (/^\/p\/\d+(?:\/[^/?#]+)?\/?$/.test(url.pathname)) return value;
  if (
    SERVICE_PREFIXES.some(
      (prefix) =>
        url.pathname === prefix || url.pathname.startsWith(`${prefix}/`),
    ) ||
    !INNER_PRODUCT_PATH.test(url.pathname)
  ) {
    return value;
  }

  url.searchParams.set(WORLD_PARAMETER, INNER_WORLD);
  return `${url.pathname}${url.search}${url.hash}`;
}
