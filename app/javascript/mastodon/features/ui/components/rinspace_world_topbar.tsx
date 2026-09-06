/* eslint-disable react/jsx-no-bind, jsx-a11y/no-noninteractive-element-interactions */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type {
  KeyboardEvent as ReactKeyboardEvent,
  SyntheticEvent,
} from 'react';

import { defineMessages, useIntl } from 'react-intl';

import { useLocation } from 'react-router-dom';

import {
  Bell,
  BellRing,
  ChevronDown,
  Kanban,
  LogOut,
  Plus,
  Search as SearchIcon,
  Settings,
  Sparkles,
  User,
} from 'lucide-react';
import { motion, useReducedMotion } from 'motion/react';

import rinspaceMark from '@/images/rinspace-mark-128.png';
import {
  RinspacePhoneAuthDialog,
  RinspaceTopbarControls,
  RinspaceTopbarFrame,
} from '@/rinspace_shared/RinspaceTopbarFrame';
import { AnimateButton } from 'mastodon/components/rinspace_animate/button';
import { AnimateThemeToggler } from 'mastodon/components/rinspace_animate/theme_toggler';
import { useTheme } from 'mastodon/hooks/useTheme';
import { useIdentity } from 'mastodon/identity_context';
import { canViewAdminDashboard } from 'mastodon/permissions';
import { selectUnreadNotificationGroupsCount } from 'mastodon/selectors/notifications';
import {
  completeRinspacePhoneOtp,
  getFreshRinspaceSession,
  isMainlandPhone,
  normalizeMainlandPhone,
  RinspaceAuthError,
  sendRinspacePhoneOtp,
  startRinspaceSso,
} from 'mastodon/services/rinspace_auth';
import type { RinspaceOtpChallenge } from 'mastodon/services/rinspace_auth';
import { useAppSelector } from 'mastodon/store';

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
  themeDark: {
    id: 'rinspace.world.theme_to_dark',
    defaultMessage: 'Switch to dark theme',
  },
  themeLight: {
    id: 'rinspace.world.theme_to_light',
    defaultMessage: 'Switch to light theme',
  },
  explore: { id: 'rinspace.world.explore', defaultMessage: 'Explore' },
  publish: { id: 'rinspace.world.publish', defaultMessage: 'Publish' },
  notifications: {
    id: 'rinspace.world.notifications',
    defaultMessage: 'Notifications',
  },
  administration: {
    id: 'navigation_bar.administration',
    defaultMessage: 'Administration',
  },
  account: { id: 'rinspace.world.account', defaultMessage: 'Your profile' },
  accountMenu: {
    id: 'rinspace.world.account_menu',
    defaultMessage: 'Account menu',
  },
  preferences: {
    id: 'navigation_bar.preferences',
    defaultMessage: 'Preferences',
  },
  signOut: { id: 'navigation_bar.sign_out', defaultMessage: 'Sign out' },
  signInOrRegister: {
    id: 'rinspace.world.sign_in_or_register',
    defaultMessage: 'Sign in / Register',
  },
  searchPlaceholder: {
    id: 'rinspace.world.search_placeholder',
    defaultMessage: 'Search people, posts, or tags',
  },
  searchLabel: { id: 'rinspace.world.search', defaultMessage: 'Search' },
  searchIndex: {
    id: 'rinspace.world.search_index',
    defaultMessage: 'Inner-world results',
  },
  searchLoading: {
    id: 'rinspace.world.search_loading',
    defaultMessage: 'Searching…',
  },
  searchEmpty: {
    id: 'rinspace.world.search_empty',
    defaultMessage: 'No matching people, posts, or tags',
  },
  searchFailed: {
    id: 'rinspace.world.search_failed',
    defaultMessage: 'Search is temporarily unavailable. Try again.',
  },
  searchPeople: {
    id: 'rinspace.world.search_people',
    defaultMessage: 'People',
  },
  searchPosts: {
    id: 'rinspace.world.search_posts',
    defaultMessage: 'Posts',
  },
  searchTags: {
    id: 'rinspace.world.search_tags',
    defaultMessage: 'Tags',
  },
  authTitle: {
    id: 'rinspace.auth.title',
    defaultMessage: 'Sign in / Register',
  },
  authPhone: { id: 'rinspace.auth.phone', defaultMessage: 'Phone number' },
  authPhonePlaceholder: {
    id: 'rinspace.auth.phone_placeholder',
    defaultMessage: 'Enter your phone number',
  },
  authCode: {
    id: 'rinspace.auth.code',
    defaultMessage: 'Verification code',
  },
  authCodePlaceholder: {
    id: 'rinspace.auth.code_placeholder',
    defaultMessage: 'SMS verification code',
  },
  authSend: {
    id: 'rinspace.auth.send_code',
    defaultMessage: 'Send code',
  },
  authComplete: {
    id: 'rinspace.auth.complete',
    defaultMessage: 'Complete sign-in',
  },
  authProcessing: {
    id: 'rinspace.auth.processing',
    defaultMessage: 'Processing…',
  },
  authChangePhone: {
    id: 'rinspace.auth.change_phone',
    defaultMessage: 'Use another phone number',
  },
  authClose: {
    id: 'rinspace.auth.close',
    defaultMessage: 'Close sign-in window',
  },
  authPhoneInvalid: {
    id: 'rinspace.auth.phone_invalid',
    defaultMessage: 'Enter an 11-digit mainland China phone number.',
  },
  authCodeInvalid: {
    id: 'rinspace.auth.code_invalid',
    defaultMessage: 'Enter the SMS verification code.',
  },
  authExisting: {
    id: 'rinspace.auth.existing',
    defaultMessage: 'Code sent. Enter it to sign in.',
  },
  authNew: {
    id: 'rinspace.auth.new',
    defaultMessage:
      'Code sent. A new account will be created for this phone number.',
  },
  authTimeout: {
    id: 'rinspace.auth.timeout',
    defaultMessage: 'The sign-in request timed out. Please try again.',
  },
  authUnavailable: {
    id: 'rinspace.auth.unavailable',
    defaultMessage: 'Rinspace sign-in is temporarily unavailable.',
  },
  authFailed: {
    id: 'rinspace.auth.failed',
    defaultMessage: 'Sign-in was not completed. Please try again.',
  },
});

interface SearchAccount {
  id: string;
  acct: string;
  display_name: string;
}

interface SearchStatus {
  id: string;
  content: string;
  account: SearchAccount;
}

interface SearchTag {
  name: string;
}

interface SearchResponse {
  accounts?: SearchAccount[];
  statuses?: SearchStatus[];
  hashtags?: SearchTag[];
}

type SearchResult =
  | {
      key: string;
      kind: 'account';
      title: string;
      detail: string;
      href: string;
    }
  | { key: string; kind: 'status'; title: string; detail: string; href: string }
  | { key: string; kind: 'tag'; title: string; detail: string; href: string };

function plainStatus(value: string) {
  return value
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
}

function toSearchResults(payload: SearchResponse): SearchResult[] {
  return [
    ...(payload.accounts ?? []).map((account) => ({
      key: `account-${account.id}`,
      kind: 'account' as const,
      title: account.display_name || account.acct,
      detail: `@${account.acct}`,
      href: innerHref(`/@${encodeURIComponent(account.acct)}`, '', ''),
    })),
    ...(payload.statuses ?? []).map((status) => ({
      key: `status-${status.id}`,
      kind: 'status' as const,
      title: plainStatus(status.content) || `@${status.account.acct}`,
      detail: `@${status.account.acct}`,
      href: `/p/${encodeURIComponent(status.id)}`,
    })),
    ...(payload.hashtags ?? []).map((tag) => ({
      key: `tag-${tag.name}`,
      kind: 'tag' as const,
      title: `#${tag.name}`,
      detail: '',
      href: innerHref(`/tags/${encodeURIComponent(tag.name)}`, '', ''),
    })),
  ].slice(0, 6);
}

const RinspaceInnerSearch: React.FC = () => {
  const intl = useIntl();
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const [results, setResults] = useState<SearchResult[]>([]);
  const form = useRef<HTMLFormElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const trimmed = query.trim();
  const resultKind = {
    account: intl.formatMessage(messages.searchPeople),
    status: intl.formatMessage(messages.searchPosts),
    tag: intl.formatMessage(messages.searchTags),
  };

  useEffect(() => {
    if (trimmed.length < 2) {
      return undefined;
    }
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      setLoading(true);
      setError(false);
      const params = new URLSearchParams({
        q: trimmed,
        resolve: 'false',
        limit: '4',
      });
      void fetch(`/api/v2/search?${params.toString()}`, {
        credentials: 'same-origin',
        signal: controller.signal,
      })
        .then(async (response) => {
          if (!response.ok) throw new Error(`search_${response.status}`);
          return (await response.json()) as SearchResponse;
        })
        .then((payload) => {
          setResults(toSearchResults(payload));
        })
        .catch((reason: unknown) => {
          if (
            !(reason instanceof DOMException && reason.name === 'AbortError')
          ) {
            setResults([]);
            setError(true);
          }
        })
        .finally(() => {
          if (!controller.signal.aborted) setLoading(false);
        });
    }, 240);
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [trimmed]);

  useEffect(() => {
    if (!open) return undefined;
    const close = (event: PointerEvent) => {
      if (
        event.target instanceof Node &&
        !form.current?.contains(event.target)
      ) {
        setOpen(false);
      }
    };
    document.addEventListener('pointerdown', close, true);
    return () => {
      document.removeEventListener('pointerdown', close, true);
    };
  }, [open]);

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!trimmed) {
      input.current?.focus();
      setOpen(true);
      return;
    }
    window.location.assign(
      innerHref('/search', `?q=${encodeURIComponent(trimmed)}`, ''),
    );
  };

  const onKeyDown = (event: ReactKeyboardEvent<HTMLFormElement>) => {
    if (event.key === 'Escape') {
      setOpen(false);
      input.current?.blur();
    }
  };

  return (
    <form
      ref={form}
      className={open ? 'topbar-search mobile-search-open' : 'topbar-search'}
      role='search'
      onSubmit={submit}
      onKeyDown={onKeyDown}
    >
      <input
        ref={input}
        value={query}
        maxLength={60}
        placeholder={intl.formatMessage(messages.searchPlaceholder)}
        aria-label={intl.formatMessage(messages.searchLabel)}
        onFocus={() => {
          setOpen(true);
        }}
        onChange={(event) => {
          setQuery(event.currentTarget.value);
        }}
      />
      <AnimateButton
        unstyled
        type='submit'
        title={intl.formatMessage(messages.searchLabel)}
        aria-label={intl.formatMessage(messages.searchLabel)}
      >
        <SearchIcon size={16} />
      </AnimateButton>
      {open && trimmed.length >= 2 ? (
        <div className='topbar-search-preview' aria-live='polite'>
          <div className='topbar-search-preview-head'>
            <span>{intl.formatMessage(messages.searchIndex)}</span>
            <span>
              {loading
                ? intl.formatMessage(messages.searchLoading)
                : results.length}
            </span>
          </div>
          {error ? (
            <p className='topbar-search-preview-note'>
              {intl.formatMessage(messages.searchFailed)}
            </p>
          ) : null}
          {!error && !loading && results.length === 0 ? (
            <p className='topbar-search-preview-note'>
              {intl.formatMessage(messages.searchEmpty)}
            </p>
          ) : null}
          {results.map((result) => (
            <a
              className='topbar-search-result'
              href={result.href}
              key={result.key}
            >
              <span>{resultKind[result.kind]}</span>
              <strong>{result.title}</strong>
              <em>{result.detail}</em>
            </a>
          ))}
        </div>
      ) : null}
    </form>
  );
};

function innerHref(pathname: string, search: string, hash: string) {
  const url = new URL(`${pathname}${search}${hash}`, window.location.origin);
  if (!url.pathname.startsWith('/p/')) url.searchParams.set('world', 'inner');
  return `${url.pathname}${url.search}${url.hash}`;
}

function innerReturnHref(pathname: string, search: string, hash: string) {
  const url = new URL(`${pathname}${search}${hash}`, window.location.origin);
  url.searchParams.delete('rinspace_login');
  url.searchParams.delete('rinspace_return_to');
  return innerHref(
    url.pathname,
    url.search,
    url.hash === '#login' ? '' : url.hash,
  );
}

function recoveredReturnHref(pathname: string, search: string, hash: string) {
  const current = new URL(
    `${pathname}${search}${hash}`,
    window.location.origin,
  );
  const requested = current.searchParams.get('rinspace_return_to');
  if (requested?.startsWith('/') && !requested.startsWith('//')) {
    const target = new URL(requested, window.location.origin);
    if (target.origin === window.location.origin) {
      return innerReturnHref(target.pathname, target.search, target.hash);
    }
  }
  return innerReturnHref(pathname, search, hash);
}

function submitSignOut() {
  const csrfParam = document.querySelector<HTMLMetaElement>(
    'meta[name="csrf-param"]',
  );
  const csrfToken = document.querySelector<HTMLMetaElement>(
    'meta[name="csrf-token"]',
  );
  if (!csrfParam?.content || !csrfToken?.content) return;

  const form = document.createElement('form');
  form.method = 'post';
  form.action = '/auth/sign_out';
  form.hidden = true;
  const fields: [string, string][] = [
    [csrfParam.content, csrfToken.content],
    ['_method', 'delete'],
  ];
  for (const [name, value] of fields) {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = name;
    input.value = value;
    form.appendChild(input);
  }
  document.body.appendChild(form);
  form.requestSubmit();
}

interface LoginDialogProps {
  open: boolean;
  returnTo: string;
  initialError: string;
  onClose: () => void;
}

const RinspaceLoginDialog: React.FC<LoginDialogProps> = ({
  open,
  returnTo,
  initialError,
  onClose,
}) => {
  const intl = useIntl();
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [challenge, setChallenge] = useState<RinspaceOtpChallenge | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(initialError);
  const [status, setStatus] = useState('');

  const friendlyError = useCallback(
    (reason: unknown) => {
      if (reason instanceof RinspaceAuthError) {
        if (reason.code === 'timeout') {
          return intl.formatMessage(messages.authTimeout);
        }
        if (reason.code === 'unavailable' || reason.code === 'storage') {
          return intl.formatMessage(messages.authUnavailable);
        }
      }
      return intl.formatMessage(messages.authFailed);
    },
    [intl],
  );

  const submit = async (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const normalizedPhone = normalizeMainlandPhone(phone);
    if (!isMainlandPhone(normalizedPhone)) {
      setError(intl.formatMessage(messages.authPhoneInvalid));
      return;
    }
    if (challenge && !/^\d{4,8}$/.test(code.trim())) {
      setError(intl.formatMessage(messages.authCodeInvalid));
      return;
    }

    setBusy(true);
    setError('');
    setStatus('');
    try {
      if (!challenge) {
        const nextChallenge = await sendRinspacePhoneOtp(normalizedPhone);
        setChallenge(nextChallenge);
        setPhone(normalizedPhone);
        setStatus(
          intl.formatMessage(
            nextChallenge.isUser ? messages.authExisting : messages.authNew,
          ),
        );
      } else {
        await completeRinspacePhoneOtp(challenge, code.trim());
        startRinspaceSso(returnTo);
      }
    } catch (reason) {
      setError(friendlyError(reason));
    } finally {
      setBusy(false);
    }
  };

  const handleSubmit = (event: SyntheticEvent<HTMLFormElement>) => {
    void submit(event);
  };

  return (
    <RinspacePhoneAuthDialog
      open={open}
      busy={busy}
      phone={phone}
      code={code}
      challenge={Boolean(challenge)}
      error={error}
      status={status}
      labels={{
        title: intl.formatMessage(messages.authTitle),
        close: intl.formatMessage(messages.authClose),
        phone: intl.formatMessage(messages.authPhone),
        phonePlaceholder: intl.formatMessage(messages.authPhonePlaceholder),
        code: intl.formatMessage(messages.authCode),
        codePlaceholder: intl.formatMessage(messages.authCodePlaceholder),
        changePhone: intl.formatMessage(messages.authChangePhone),
        processing: intl.formatMessage(messages.authProcessing),
        complete: intl.formatMessage(messages.authComplete),
        sendCode: intl.formatMessage(messages.authSend),
      }}
      onClose={onClose}
      onPhoneChange={setPhone}
      onCodeChange={setCode}
      onChangePhone={() => {
        setChallenge(null);
        setCode('');
        setStatus('');
        setError('');
      }}
      onSubmit={handleSubmit}
    />
  );
};

export const RinspaceWorldTopbar: React.FC<{
  avatar?: string;
  displayName?: string;
  username?: string;
}> = ({ avatar, displayName, username }) => {
  const intl = useIntl();
  const reducedMotion = useReducedMotion();
  const location = useLocation();
  const theme = useTheme();
  const { signedIn, permissions } = useIdentity();
  const unreadNotifications = useAppSelector(
    selectUnreadNotificationGroupsCount,
  );
  const [loginOpen, setLoginOpen] = useState(() => {
    const recovery = new URLSearchParams(location.search).get('rinspace_login');
    return !signedIn && (location.hash === '#login' || recovery === '1');
  });
  const [loginError, setLoginError] = useState('');
  const [loginBusy, setLoginBusy] = useState(false);
  const loginTrigger = useRef<HTMLButtonElement>(null);
  const closeLogin = useCallback(() => {
    setLoginOpen(false);
    window.requestAnimationFrame(() => loginTrigger.current?.focus());
  }, []);
  const returnTo = useMemo(
    () =>
      recoveredReturnHref(location.pathname, location.search, location.hash),
    [location.hash, location.pathname, location.search],
  );

  useEffect(() => {
    const stored = window.localStorage.getItem('rinspace-inner-color-scheme');
    if (stored === 'light' || stored === 'dark') {
      document.documentElement.dataset.colorScheme = stored;
      document.documentElement.dataset.systemTheme = 'false';
    }
  }, []);

  const toggleTheme = () => {
    const next = theme === 'light' ? 'dark' : 'light';
    document.documentElement.dataset.colorScheme = next;
    document.documentElement.dataset.systemTheme = 'false';
    window.localStorage.setItem('rinspace-inner-color-scheme', next);
  };

  const beginLogin = async () => {
    if (loginBusy) return;
    setLoginBusy(true);
    setLoginError('');
    try {
      const session = await getFreshRinspaceSession();
      if (session) {
        startRinspaceSso(returnTo);
        return;
      }
      setLoginOpen(true);
    } catch (reason) {
      setLoginError(
        reason instanceof RinspaceAuthError && reason.code === 'timeout'
          ? intl.formatMessage(messages.authTimeout)
          : intl.formatMessage(messages.authFailed),
      );
      setLoginOpen(true);
    } finally {
      setLoginBusy(false);
    }
  };

  const canAdmin = canViewAdminDashboard(permissions);
  const accountName = displayName?.trim()
    ? displayName.trim()
    : (username ?? '');

  return (
    <>
      <RinspaceTopbarFrame
        sessionState={signedIn ? 'authenticated' : 'anonymous'}
        logoSrc={rinspaceMark}
        brandName={intl.formatMessage(messages.brandName)}
        flipHref='/'
        homeHref='/?world=inner'
        flipLabel={intl.formatMessage(messages.flip)}
        homeLabel={intl.formatMessage(messages.home)}
      >
        <RinspaceTopbarControls
          navigationLabel={intl.formatMessage(messages.navigation)}
          search={<RinspaceInnerSearch />}
        >
          <AnimateThemeToggler
            className='topbar-pill'
            label={intl.formatMessage(
              theme === 'light' ? messages.themeDark : messages.themeLight,
            )}
            resolved={theme}
            onToggle={toggleTheme}
          />

          {signedIn ? (
            <>
              <motion.a
                className='topbar-pill'
                href={innerHref('/explore', '', '')}
                aria-label={intl.formatMessage(messages.explore)}
                title={intl.formatMessage(messages.explore)}
                whileHover={reducedMotion ? undefined : { y: -1 }}
                whileTap={reducedMotion ? undefined : { scale: 0.94 }}
              >
                <Sparkles size={18} />
              </motion.a>
              <motion.a
                className='topbar-pill'
                href={innerHref('/publish', '', '')}
                aria-label={intl.formatMessage(messages.publish)}
                title={intl.formatMessage(messages.publish)}
                whileHover={reducedMotion ? undefined : { y: -1 }}
                whileTap={reducedMotion ? undefined : { scale: 0.94 }}
              >
                <Plus size={16} />
              </motion.a>
              <motion.a
                className='notification-pill'
                href={innerHref('/notifications', '', '')}
                aria-label={intl.formatMessage(messages.notifications)}
                title={intl.formatMessage(messages.notifications)}
                whileHover={reducedMotion ? undefined : { y: -1 }}
                whileTap={reducedMotion ? undefined : { scale: 0.94 }}
              >
                {unreadNotifications > 0 ? (
                  <BellRing size={16} />
                ) : (
                  <Bell size={16} />
                )}
                {unreadNotifications > 0 ? (
                  <span>
                    {unreadNotifications > 99 ? '99+' : unreadNotifications}
                  </span>
                ) : null}
              </motion.a>
              {canAdmin ? (
                <motion.a
                  className='notification-pill'
                  href={innerHref('/admin', '', '')}
                  aria-label={intl.formatMessage(messages.administration)}
                  title={intl.formatMessage(messages.administration)}
                  whileHover={reducedMotion ? undefined : { y: -1 }}
                  whileTap={reducedMotion ? undefined : { scale: 0.94 }}
                >
                  <Kanban size={16} />
                </motion.a>
              ) : null}
              {username ? (
                <details className='account-menu'>
                  <summary
                    className='account-menu-trigger'
                    aria-label={intl.formatMessage(messages.accountMenu)}
                  >
                    <span className='avatar-name'>
                      <span className='avatar-name-mark' aria-hidden='true'>
                        {avatar ? (
                          <img src={avatar} alt='' />
                        ) : (
                          username.slice(0, 1).toUpperCase()
                        )}
                      </span>
                      <span className='avatar-name-text'>{accountName}</span>
                    </span>
                    <ChevronDown size={16} aria-hidden='true' />
                  </summary>
                  <div className='rin-account-menu' role='menu'>
                    <a
                      role='menuitem'
                      href={innerHref(
                        `/@${encodeURIComponent(username)}`,
                        '',
                        '',
                      )}
                    >
                      <User size={16} />
                      {intl.formatMessage(messages.account)}
                    </a>
                    <a
                      role='menuitem'
                      href={innerHref(
                        '/settings/preferences/appearance',
                        '',
                        '',
                      )}
                    >
                      <Settings size={16} />
                      {intl.formatMessage(messages.preferences)}
                    </a>
                    <button
                      type='button'
                      role='menuitem'
                      onClick={submitSignOut}
                    >
                      <LogOut size={16} />
                      {intl.formatMessage(messages.signOut)}
                    </button>
                  </div>
                </details>
              ) : null}
            </>
          ) : (
            <AnimateButton
              ref={loginTrigger}
              unstyled
              type='button'
              className='topbar-auth-button'
              disabled={loginBusy}
              onClick={() => void beginLogin()}
            >
              {intl.formatMessage(messages.signInOrRegister)}
            </AnimateButton>
          )}
        </RinspaceTopbarControls>
      </RinspaceTopbarFrame>
      {loginOpen ? (
        <RinspaceLoginDialog
          open
          returnTo={returnTo}
          initialError={loginError}
          onClose={closeLogin}
        />
      ) : null}
    </>
  );
};
