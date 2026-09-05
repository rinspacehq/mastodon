import { resolveWorld } from '@rinspace/world-shell';

const WORLD_PARAMETER = 'world';
const INNER_WORLD = 'inner';

/**
 * Canonicalize a Mastodon-side navigation without guessing route ownership.
 * Only dual-sided resources gain an explicit world selector; inner-only routes
 * such as `/p/:id` remain path-owned.
 */
export function innerWorldPath(value: string) {
  const url = new URL(value, window.location.origin);
  url.searchParams.set(WORLD_PARAMETER, INNER_WORLD);

  const resolution = resolveWorld(
    `${url.pathname}${url.search}${url.hash}`,
  );

  return resolution.route?.kind === 'dual'
    ? resolution.canonicalHref
    : value;
}
