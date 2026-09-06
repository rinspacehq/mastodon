import { describe, expect, it } from 'vitest';

import { innerWorldPath } from './world_path';

describe('innerWorldPath', () => {
  it.each([
    ['/@alice', '/@alice?world=inner'],
    ['/@alice/media#latest', '/@alice/media?world=inner#latest'],
    ['/tags/books?tab=recent', '/tags/books?tab=recent&world=inner'],
    ['/settings/profile', '/settings/profile?world=inner'],
    ['/notifications', '/notifications?world=inner'],
    ['/search?q=reverse+engineering', '/search?q=reverse+engineering&world=inner'],
    ['/relationships', '/relationships?world=inner'],
    ['/statuses_cleanup', '/statuses_cleanup?world=inner'],
    ['/terms-of-service', '/terms-of-service?world=inner'],
  ])('keeps dual resource %s in the inner world', (input, expected) => {
    expect(innerWorldPath(input)).toBe(expected);
  });

  it.each(['/p/123', '/p/123/readable']) (
    'does not add a selector to permanent post resource %s',
    (input) => {
      expect(innerWorldPath(input)).toBe(input);
    },
  );

  it('keeps APIs outside world-page canonicalization', () => {
    expect(innerWorldPath('/api/v1/timelines/home')).toBe('/api/v1/timelines/home');
  });
});
