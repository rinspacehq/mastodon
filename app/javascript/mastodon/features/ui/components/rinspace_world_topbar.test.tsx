import { IntlProvider } from 'react-intl';

import { MemoryRouter } from 'react-router-dom';

import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { innerHref, RinspaceWorldTopbar } from './rinspace_world_topbar';

const adapterState = vi.hoisted(() => ({
  signedIn: false,
  permissions: 0,
  unreadNotifications: 0,
  rinspaceSession: null as null | { access_token: string },
}));

const startSso = vi.hoisted(() => vi.fn());

vi.mock('mastodon/hooks/useTheme', () => ({ useTheme: () => 'light' }));

vi.mock('mastodon/identity_context', () => ({
  useIdentity: () => ({
    signedIn: adapterState.signedIn,
    permissions: adapterState.permissions,
  }),
}));

vi.mock('mastodon/services/rinspace_auth', () => ({
  completeRinspacePhoneOtp: vi.fn(),
  getFreshRinspaceSession: () => Promise.resolve(adapterState.rinspaceSession),
  isMainlandPhone: (phone: string) => /^1\d{10}$/.test(phone),
  normalizeMainlandPhone: (phone: string) => phone,
  RinspaceAuthError: class extends Error {},
  sendRinspacePhoneOtp: vi.fn(),
  startRinspaceSso: startSso,
}));

vi.mock('mastodon/selectors/notifications', () => ({
  selectUnreadNotificationGroupsCount: Symbol('unread-notifications'),
}));

vi.mock('mastodon/store', () => ({
  useAppSelector: () => adapterState.unreadNotifications,
}));

function renderTopbar(entry = '/explore?world=inner#latest') {
  return render(
    <IntlProvider locale='en'>
      <MemoryRouter initialEntries={[entry]}>
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
    adapterState.permissions = 0;
    adapterState.unreadNotifications = 0;
    adapterState.rinspaceSession = null;
    startSso.mockClear();
    window.localStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('keeps the outer presentation controls and opens sign-in in place', async () => {
    const { container } = renderTopbar();

    expect(screen.getByRole('search').classList.contains('topbar-search')).toBe(
      true,
    );
    expect(
      container.querySelector<HTMLImageElement>('.brand-mark img')?.src,
    ).toContain('/images/rinspace-mark-128.png');
    expect(
      screen.getByRole('button', { name: 'Switch to dark theme' }),
    ).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Explore' })).toBeNull();

    fireEvent.click(screen.getByRole('button', { name: 'Sign in / Register' }));

    expect(
      await screen.findByRole('dialog', { name: 'Sign in / Register' }),
    ).toBeTruthy();
    expect(screen.getByLabelText('Phone number')).toBeTruthy();
  });

  it('searches the real Mastodon endpoint and keeps result routes in the inner world', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          accounts: [
            { id: '1', acct: 'reverse', display_name: 'Reverse Engineer' },
          ],
          statuses: [],
          hashtags: [{ name: 'reverseengineering' }],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
    renderTopbar();

    const search = screen.getByRole('textbox', { name: 'Search' });
    fireEvent.focus(search);
    fireEvent.change(search, {
      target: { value: 'reverse engineering' },
    });

    expect(await screen.findByText('Reverse Engineer')).toBeTruthy();
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v2/search?q=reverse+engineering&resolve=false&limit=4',
      expect.objectContaining({ credentials: 'same-origin' }),
    );
    expect(
      screen
        .getByRole('link', { name: /Reverse Engineer/ })
        .getAttribute('href'),
    ).toBe('/@reverse?world=inner');
    expect(
      screen
        .getByRole('link', { name: /#reverseengineering/ })
        .getAttribute('href'),
    ).toBe('/tags/reverseengineering?world=inner');
  });

  it('uses an existing outer session and preserves the exact inner return URL', async () => {
    adapterState.rinspaceSession = { access_token: 'access' };
    renderTopbar('/search?q=reverse%20engineering&world=inner#results');

    fireEvent.click(screen.getByRole('button', { name: 'Sign in / Register' }));

    await waitFor(() => {
      expect(startSso).toHaveBeenCalledWith(
        '/search?q=reverse+engineering&world=inner#results',
      );
    });
  });

  it('opens the inner-world login dialog from the no-JavaScript recovery URL', async () => {
    renderTopbar('/?world=inner#login');

    expect(
      await screen.findByRole('dialog', { name: 'Sign in / Register' }),
    ).toBeTruthy();
  });

  it('removes the recovery marker but preserves the original URL after sign-in', async () => {
    adapterState.rinspaceSession = { access_token: 'access' };
    renderTopbar(
      '/search?q=reverse+engineering&world=inner&rinspace_login=1#results',
    );
    expect(
      await screen.findByRole('dialog', { name: 'Sign in / Register' }),
    ).toBeTruthy();

    fireEvent.click(
      screen.getByRole('button', { name: 'Close sign-in window' }),
    );
    fireEvent.click(screen.getByRole('button', { name: 'Sign in / Register' }));

    await waitFor(() => {
      expect(startSso).toHaveBeenCalledWith(
        '/search?q=reverse+engineering&world=inner#results',
      );
    });
  });

  it('opens recovery in the public shell and submits the protected inner target', async () => {
    adapterState.rinspaceSession = { access_token: 'access' };
    renderTopbar(
      '/?world=inner&rinspace_login=1&rinspace_return_to=%2Fsettings%2Fpreferences%2Fappearance%3Fworld%3Dinner',
    );
    expect(
      await screen.findByRole('dialog', { name: 'Sign in / Register' }),
    ).toBeTruthy();

    fireEvent.click(
      screen.getByRole('button', { name: 'Close sign-in window' }),
    );
    fireEvent.click(screen.getByRole('button', { name: 'Sign in / Register' }));

    await waitFor(() => {
      expect(startSso).toHaveBeenCalledWith(
        '/settings/preferences/appearance?world=inner',
      );
    });
  });

  it('closes the login dialog with Escape and restores trigger focus', async () => {
    renderTopbar();
    const trigger = screen.getByRole('button', { name: 'Sign in / Register' });
    trigger.focus();
    fireEvent.click(trigger);
    await screen.findByRole('dialog', { name: 'Sign in / Register' });

    fireEvent.keyDown(document, { key: 'Escape' });

    await waitFor(() => {
      expect(
        screen.queryByRole('dialog', { name: 'Sign in / Register' }),
      ).toBeNull();
      expect(document.activeElement).toBe(trigger);
    });
  });

  it('binds the complete signed-in control order to Mastodon routes', () => {
    adapterState.signedIn = true;
    adapterState.unreadNotifications = 7;
    renderTopbar();

    const navigation = screen.getByRole('navigation');
    const controls = Array.from(navigation.children).map((element) =>
      (element.matches('details')
        ? element.querySelector('summary')
        : element
      )?.getAttribute('aria-label'),
    );
    expect(controls).toEqual([
      'Switch to dark theme',
      'Explore',
      'Publish',
      'Notifications',
      'Account menu',
    ]);
    expect(
      screen.getByRole('link', { name: 'Explore' }).getAttribute('href'),
    ).toBe('/explore?world=inner');
    expect(screen.getByRole('button', { name: 'Publish' })).toBeTruthy();
    expect(innerHref('/publish', '', '')).toBe('/publish?world=inner');
    expect(
      screen.getByRole('link', { name: 'Notifications' }).getAttribute('href'),
    ).toBe('/notifications?world=inner');
    expect(
      screen
        .getByRole('menuitem', { name: 'Preferences' })
        .getAttribute('href'),
    ).toBe('/settings/preferences/appearance?world=inner');
    expect(screen.getByText('7')).toBeTruthy();
  });

  it('adds administration only for a role that can view the dashboard', () => {
    adapterState.signedIn = true;
    adapterState.permissions = 0x0000000000000008;
    renderTopbar();

    expect(
      screen.getByRole('link', { name: 'Administration' }).getAttribute('href'),
    ).toBe('/admin?world=inner');
  });
});
