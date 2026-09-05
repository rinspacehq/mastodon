import { describe, expect, it } from 'vitest';

import { innerWorldPath } from './world_path';

describe('innerWorldPath', () => {
  it.each([
    ['/@alice', '/@alice?world=inner'],
    ['/@alice/media#latest', '/@alice/media#latest'],
    ['/tags/books?tab=recent', '/tags/books?tab=recent&world=inner'],
  ])('keeps dual resource %s in the inner world', (input, expected) => {
    expect(innerWorldPath(input)).toBe(expected);
  });

  it.each(['/p/123/readable', '/settings/profile']) (
    'does not add a selector to path-owned resource %s',
    (input) => {
      expect(innerWorldPath(input)).toBe(input);
    },
  );

  it('keeps notifications path-owned by the inner runtime', () => {
    expect(innerWorldPath('/notifications')).toBe('/notifications');
  });
});
