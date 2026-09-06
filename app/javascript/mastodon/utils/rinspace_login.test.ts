import { describe, expect, it, vi } from 'vitest';

import { rinspaceLoginHref, rinspaceLoginMethod } from './rinspace_login';

describe('Rinspace login entry adapter', () => {
  it('preserves an inner route when entering the shared recovery flow', () => {
    vi.stubGlobal(
      'location',
      new URL('https://rinspace.com/explore?world=inner#links'),
    );

    expect(rinspaceLoginHref('/auth/rinspace/recover')).toBe(
      '/auth/rinspace/recover?return_to=%2Fexplore%3Fworld%3Dinner%23links',
    );
    expect(rinspaceLoginMethod('/auth/rinspace/recover')).toBeUndefined();
  });

  it('keeps stable post permalinks free of the world query', () => {
    vi.stubGlobal('location', new URL('https://rinspace.com/p/123/example'));

    expect(rinspaceLoginHref('/auth/rinspace/recover')).toBe(
      '/auth/rinspace/recover?return_to=%2Fp%2F123%2Fexample',
    );
  });

  it('retains POST for non-Rinspace OmniAuth providers', () => {
    expect(rinspaceLoginHref('/auth/auth/example')).toBe('/auth/auth/example');
    expect(rinspaceLoginMethod('/auth/auth/example')).toBe('post');
  });
});
