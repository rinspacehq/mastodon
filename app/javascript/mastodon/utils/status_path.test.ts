import { describe, expect, it } from 'vitest';

import { statusPathFromUrl } from './status_path';

describe('statusPathFromUrl', () => {
  it('uses the canonical same-origin path supplied by the REST status', () => {
    expect(
      statusPathFromUrl('123', `${window.location.origin}/p/123/readable-post`),
    ).toBe('/p/123/readable-post');
  });

  it('falls back to the stable short URL when a URL is absent or external', () => {
    expect(statusPathFromUrl('123', null)).toBe('/p/123');
    expect(statusPathFromUrl('123', 'https://remote.example/@a/123')).toBe(
      '/p/123',
    );
  });
});
