import { resolveWorld } from '@rinspace/world-shell';

const WORLD_PARAMETER = 'world';
const INNER_WORLD = 'inner';

/**
 * Canonicalize a Mastodon-side navigation without guessing route ownership.
 * Every Mastodon product page gains an explicit world selector except for the
 * stable `/p/:id[/slug]` permalink family. Service URLs remain untouched.
 */
export function innerWorldPath(value: string) {
  const url = new URL(value, window.location.origin);
  url.searchParams.set(WORLD_PARAMETER, INNER_WORLD);

  const resolution = resolveWorld(
    `${url.pathname}${url.search}${url.hash}`,
  );

  return resolution.world === INNER_WORLD
    ? resolution.canonicalHref
    : value;
}
