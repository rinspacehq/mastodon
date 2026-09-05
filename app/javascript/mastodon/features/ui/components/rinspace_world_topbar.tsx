import { useCallback, useEffect, useMemo, useState } from 'react';

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
import '@rinspace/world-shell/styles.css';

const messages = defineMessages({
  navigation: { id: 'rinspace.world.navigation', defaultMessage: 'Rinspace inner-world navigation' },
  flip: { id: 'rinspace.world.flip_to_outer', defaultMessage: 'Flip to the outer world' },
  home: { id: 'rinspace.world.inner_home', defaultMessage: 'Go to the inner-world home' },
  search: { id: 'rinspace.world.search', defaultMessage: 'Search the inner world' },
  searchPlaceholder: { id: 'rinspace.world.search_placeholder', defaultMessage: 'Search people, posts, and tags' },
  publish: { id: 'rinspace.world.publish', defaultMessage: 'Publish' },
  notifications: { id: 'rinspace.world.notifications', defaultMessage: 'Notifications' },
  account: { id: 'rinspace.world.account', defaultMessage: 'Your profile' },
});

function innerHref(pathname: string, search: string, hash: string) {
  const url = new URL(`${pathname}${search}${hash}`, window.location.origin);
  url.searchParams.set('world', 'inner');
  return `${url.pathname}${url.search}${url.hash}`;
}

export const RinspaceWorldTopbar: React.FC<{ username?: string }> = ({
  username,
}) => {
  const intl = useIntl();
  const location = useLocation();
  const [query, setQuery] = useState('');

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
  const submitSearch = useCallback((event: React.SyntheticEvent<HTMLFormElement, SubmitEvent>) => {
    if (!query.trim()) event.preventDefault();
  }, [query]);
  const changeSearch = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    setQuery(event.currentTarget.value);
  }, []);

  return (
    <RinspaceTopbar
      brandName='Rinspace'
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
        search: (
          <form
            className='rinspace-world-topbar__search'
            action='/search'
            method='get'
            onSubmit={submitSearch}
          >
            <input type='hidden' name='world' value='inner' />
            <input
              name='q'
              type='search'
              value={query}
              onChange={changeSearch}
              aria-label={intl.formatMessage(messages.search)}
              placeholder={intl.formatMessage(messages.searchPlaceholder)}
            />
          </form>
        ),
        publishing: <a href='/publish'>{intl.formatMessage(messages.publish)}</a>,
        notifications: <a href='/notifications'>{intl.formatMessage(messages.notifications)}</a>,
        session: username ? (
          <a href={`/@${encodeURIComponent(username)}?world=inner`}>
            <span aria-hidden='true'>@{username}</span>
            <span className='sr-only'>{intl.formatMessage(messages.account)}</span>
          </a>
        ) : undefined,
      }}
    />
  );
};
