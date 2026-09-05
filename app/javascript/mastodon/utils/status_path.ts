import type { AccountStatusShape } from '@/mastodon/models/status';

export function statusPath(status: Pick<AccountStatusShape, 'id' | 'url'>) {
  return statusPathFromUrl(status.id, status.url);
}

export function statusPathFromUrl(id: string, value: string | null) {
  if (value) {
    const url = new URL(value, window.location.origin);
    if (url.origin === window.location.origin) {
      return `${url.pathname}${url.search}${url.hash}`;
    }
  }

  return `/p/${encodeURIComponent(id)}`;
}
