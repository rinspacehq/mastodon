import { describe, expect, it, vi } from 'vitest';

import { browserHistory } from './router';

vi.mock('../initial_state', () => ({
  forceSingleColumn: true,
  hasMultiColumnPath: false,
}));

describe('inner-world search history', () => {
  it('keeps the search page when pushing and replacing filters', () => {
    browserHistory.replace('/search?q=word&world=inner');

    browserHistory.push({ search: '?q=word&type=statuses' });
    expect(browserHistory.location.pathname).toBe('/search');
    expect(new URLSearchParams(browserHistory.location.search).get('world')).toBe(
      'inner',
    );
    expect(new URLSearchParams(browserHistory.location.search).get('type')).toBe(
      'statuses',
    );

    browserHistory.replace({ search: '?q=word&type=hashtags', hash: '#results' });
    expect(browserHistory.location).toMatchObject({
      pathname: '/search',
      hash: '#results',
    });
    expect(new URLSearchParams(browserHistory.location.search).get('type')).toBe(
      'hashtags',
    );
  });
});
