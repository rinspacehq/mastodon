import { IntlProvider } from 'react-intl';

import { MemoryRouter } from 'react-router-dom';

import { render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { RinspaceWorldTopbar } from './rinspace_world_topbar';

const adapterState = vi.hoisted(() => ({
  signedIn: false,
  unreadNotifications: 0,
}));

vi.mock('mastodon/features/compose/components/search', () => ({
  Search: ({ topbar }: { topbar?: boolean }) => (
    <form role='search' data-topbar={String(topbar)}>
      <input aria-label='Search' />
    </form>
  ),
}));

vi.mock('mastodon/identity_context', () => ({
  useIdentity: () => ({ signedIn: adapterState.signedIn }),
}));

vi.mock('mastodon/initial_state', () => ({
  sso_redirect: '/auth/auth/openid_connect',
}));

vi.mock('mastodon/selectors/notifications', () => ({
  selectUnreadNotificationGroupsCount: Symbol('unread-notifications'),
}));

vi.mock('mastodon/store', () => ({
  useAppSelector: () => adapterState.unreadNotifications,
}));

function renderTopbar() {
  return render(
    <IntlProvider locale='en'>
      <MemoryRouter initialEntries={['/?world=inner']}>
        <RinspaceWorldTopbar
          avatar='/avatar.png'
          displayName='Rin Reader'
          username='reader'
        />
      </MemoryRouter>
    </IntlProvider>,
  );
}

describe('RinspaceWorldTopbar', () => {
  beforeEach(() => {
    adapterState.signedIn = false;
    adapterState.unreadNotifications = 0;
  });

  it('uses Mastodon search and the real SSO entry for signed-out visitors', () => {
    renderTopbar();

    expect(screen.getByRole('search').dataset.topbar).toBe('true');
    expect(
      screen
        .getByRole('link', { name: 'Sign in / Register' })
        .getAttribute('href'),
    ).toBe('/auth/auth/openid_connect');
    expect(screen.queryByRole('link', { name: 'Publish' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Notifications' })).toBeNull();
  });

  it('binds publishing, unread notifications, and profile to Mastodon routes', () => {
    adapterState.signedIn = true;
    adapterState.unreadNotifications = 7;

    renderTopbar();

    expect(
      screen.getByRole('link', { name: 'Publish' }).getAttribute('href'),
    ).toBe('/publish?world=inner');
    expect(
      screen.getByRole('link', { name: 'Notifications' }).getAttribute('href'),
    ).toBe('/notifications?world=inner');
    expect(screen.getByText('7')).toBeTruthy();
    expect(
      screen.getByRole('link', { name: 'Your profile' }).getAttribute('href'),
    ).toBe('/@reader?world=inner');
  });
});
