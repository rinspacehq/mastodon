import { describe, expect, it, vi } from 'vitest';

import {
  handleRinspaceLoginClick,
  requestRinspaceLogin,
  RINSPACE_LOGIN_REQUEST_EVENT,
  rinspaceLoginHref,
  rinspaceLoginMethod,
  usesRinspaceLogin,
} from './rinspace_login';

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

  it('opens the in-place Rinspace login adapter and keeps the recovery URL as a no-JavaScript fallback', () => {
    const listener = vi.fn((event: Event) => {
      event.preventDefault();
    });
    const preventDefault = vi.fn();
    window.addEventListener(RINSPACE_LOGIN_REQUEST_EVENT, listener);

    expect(usesRinspaceLogin('/auth/rinspace/recover')).toBe(true);
    handleRinspaceLoginClick({ preventDefault }, '/auth/rinspace/recover');

    expect(preventDefault).toHaveBeenCalledOnce();
    expect(listener).toHaveBeenCalledOnce();
    window.removeEventListener(RINSPACE_LOGIN_REQUEST_EVENT, listener);
  });

  it('does not intercept another OmniAuth provider', () => {
    const listener = vi.fn();
    const preventDefault = vi.fn();
    window.addEventListener(RINSPACE_LOGIN_REQUEST_EVENT, listener);

    expect(requestRinspaceLogin('/auth/auth/example')).toBe(false);
    handleRinspaceLoginClick({ preventDefault }, '/auth/auth/example');

    expect(preventDefault).not.toHaveBeenCalled();
    expect(listener).not.toHaveBeenCalled();
    window.removeEventListener(RINSPACE_LOGIN_REQUEST_EVENT, listener);
  });
});
