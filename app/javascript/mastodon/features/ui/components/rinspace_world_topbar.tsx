import { useCallback, useEffect, useMemo } from 'react';

import { defineMessages, useIntl } from 'react-intl';

import { useLocation } from 'react-router-dom';

import {
  RinspaceTopbar,
  flipTarget,
  installWorldTransitionLifecycle,
  prepareWorldFlipNavigation,
  resolveWorld,
} from '@rinspace/world-shell';
import type { WorldNavigationRequest } from '@rinspace/world-shell';

import AddIcon from '@/material-icons/400-24px/add.svg?react';
import NotificationsIcon from '@/material-icons/400-24px/notifications.svg?react';
import { Search } from 'mastodon/features/compose/components/search';
import { useIdentity } from 'mastodon/identity_context';
import { sso_redirect } from 'mastodon/initial_state';
import { selectUnreadNotificationGroupsCount } from 'mastodon/selectors/notifications';
import { useAppSelector } from 'mastodon/store';

import '@rinspace/world-shell/styles.css';

const messages = defineMessages({
  brandName: { id: 'rinspace.world.brand_name', defaultMessage: 'Rinspace' },
  navigation: {
    id: 'rinspace.world.navigation',
    defaultMessage: 'Rinspace inner-world navigation',
  },
  flip: {
    id: 'rinspace.world.flip_to_outer',
    defaultMessage: 'Flip to the outer world',
  },
  home: {
    id: 'rinspace.world.inner_home',
    defaultMessage: 'Go to the inner-world home',
  },
  publish: { id: 'rinspace.world.publish', defaultMessage: 'Publish' },
  notifications: {
    id: 'rinspace.world.notifications',
    defaultMessage: 'Notifications',
  },
  account: { id: 'rinspace.world.account', defaultMessage: 'Your profile' },
  signInOrRegister: {
    id: 'rinspace.world.sign_in_or_register',
    defaultMessage: 'Sign in / Register',
  },
});

function innerHref(pathname: string, search: string, hash: string) {
  const url = new URL(`${pathname}${search}${hash}`, window.location.origin);
  url.searchParams.set('world', 'inner');
  return `${url.pathname}${url.search}${url.hash}`;
}

export const RinspaceWorldTopbar: React.FC<{
  avatar?: string;
  displayName?: string;
  username?: string;
}> = ({ avatar, displayName, username }) => {
  const intl = useIntl();
  const location = useLocation();
  const { signedIn } = useIdentity();
  const unreadNotifications = useAppSelector(
    selectUnreadNotificationGroupsCount,
  );
  const brandName = intl.formatMessage(messages.brandName);

  useEffect(() => installWorldTransitionLifecycle(), []);

  const current = useMemo(
    () => innerHref(location.pathname, location.search, location.hash),
    [location.hash, location.pathname, location.search],
  );
  const resolution = useMemo(() => resolveWorld(current), [current]);
  const flipHref = flipTarget(current, resolution) ?? '/';
  const navigate = useCallback(({ href, reason }: WorldNavigationRequest) => {
    if (reason === 'flip') prepareWorldFlipNavigation(href);
    return false;
  }, []);

  return (
    <RinspaceTopbar
      brandName={brandName}
      brandMark={
        <img
          src='/assets/brand/rinspace-mark-128.png'
          alt=''
          width='128'
          height='128'
          draggable={false}
        />
      }
      brandWordmark={brandName}
      world='inner'
      currentHomeHref='/?world=inner'
      flipHref={flipHref}
      labels={{
        navigation: intl.formatMessage(messages.navigation),
        flip: intl.formatMessage(messages.flip),
        home: intl.formatMessage(messages.home),
      }}
      ports={{
        navigation: {
          navigate,
        },
      }}
      slots={{
        search: <Search singleColumn topbar />,
        publishing: signedIn ? (
          <a
            className='rin-world-shell__action'
            href={innerHref('/publish', '', '')}
            aria-label={intl.formatMessage(messages.publish)}
            title={intl.formatMessage(messages.publish)}
          >
            <AddIcon />
          </a>
        ) : undefined,
        notifications: signedIn ? (
          <a
            className='rin-world-shell__action'
            href={innerHref('/notifications', '', '')}
            aria-label={intl.formatMessage(messages.notifications)}
            title={intl.formatMessage(messages.notifications)}
          >
            <NotificationsIcon />
            {unreadNotifications > 0 ? (
              <span className='rin-world-shell__badge'>
                {unreadNotifications > 99 ? '99+' : unreadNotifications}
              </span>
            ) : null}
          </a>
        ) : undefined,
        session:
          signedIn && username ? (
            <a
              className='rin-world-shell__account'
              href={innerHref(`/@${encodeURIComponent(username)}`, '', '')}
              aria-label={intl.formatMessage(messages.account)}
            >
              <span className='rin-world-shell__avatar' aria-hidden='true'>
                {avatar ? (
                  <img src={avatar} alt='' />
                ) : (
                  username.slice(0, 1).toUpperCase()
                )}
              </span>
              <span
                className='rin-world-shell__account-name'
                aria-hidden='true'
              >
                {displayName?.trim() ? displayName : username}
              </span>
              <span className='sr-only'>
                {intl.formatMessage(messages.account)}
              </span>
            </a>
          ) : signedIn ? undefined : (
            <a
              className='rin-world-shell__sign-in'
              href={sso_redirect ?? '/auth/sign_in'}
              data-method={sso_redirect ? 'post' : undefined}
            >
              {intl.formatMessage(messages.signInOrRegister)}
            </a>
          ),
      }}
    />
  );
};
