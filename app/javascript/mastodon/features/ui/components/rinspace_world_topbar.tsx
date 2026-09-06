/* eslint-disable react/jsx-no-bind */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SyntheticEvent } from 'react';
import { createPortal } from 'react-dom';

import { defineMessages, useIntl } from 'react-intl';

import { useLocation } from 'react-router-dom';

import {
  BellIcon,
  CaretDownIcon,
  CompassIcon,
  GaugeIcon,
  GearIcon,
  PlusIcon,
  SignOutIcon,
  UserIcon,
} from '@phosphor-icons/react';
import { motion, useReducedMotion } from 'motion/react';

import { AnimateButton } from 'mastodon/components/rinspace_animate/button';
import { SplittingText } from 'mastodon/components/rinspace_animate/splitting_text';
import { AnimateThemeToggler } from 'mastodon/components/rinspace_animate/theme_toggler';
import { Search } from 'mastodon/features/compose/components/search';
import { useTheme } from 'mastodon/hooks/useTheme';
import { useIdentity } from 'mastodon/identity_context';
import { customAppIcon } from 'mastodon/initial_state';
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

/**
 * Presentation snapshot copied from private rinspace/ui at 3aedfb63.
 * Source files and SHA-256 values are recorded in the private product spec.
 * Only Mastodon state, routing, internationalization and auth are adapted.
 */

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
  const reducedMotion = useReducedMotion();
  const dialog = useRef<HTMLElement>(null);
  const phoneInput = useRef<HTMLInputElement>(null);
  const busyRef = useRef(false);
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [challenge, setChallenge] = useState<RinspaceOtpChallenge | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(initialError);
  const [status, setStatus] = useState('');

  useEffect(() => {
    busyRef.current = busy;
  }, [busy]);

  useEffect(() => {
    if (!open) return undefined;
    const active = document.activeElement as HTMLElement | null;
    const focusFrame = window.requestAnimationFrame(() =>
      phoneInput.current?.focus(),
    );
    const handleDialogKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !busyRef.current) {
        onClose();
        return;
      }
      if (event.key !== 'Tab') return;
      const focusable = Array.from(
        dialog.current?.querySelectorAll<HTMLElement>(
          'button:not(:disabled), input:not(:disabled), [href], [tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable.at(-1);
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    };
    document.addEventListener('keydown', handleDialogKey);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener('keydown', handleDialogKey);
      active?.focus();
    };
  }, [onClose, open]);

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

  if (!open) return null;
  return createPortal(
    <motion.div
      className='rin-auth-overlay'
      initial={reducedMotion ? false : { opacity: 0 }}
      animate={{ opacity: 1 }}
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !busy) onClose();
      }}
    >
      <motion.section
        ref={dialog}
        className='rin-auth-dialog'
        role='dialog'
        aria-modal='true'
        aria-labelledby='rin-auth-dialog-title'
        initial={reducedMotion ? false : { opacity: 0, y: 10, scale: 0.985 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: reducedMotion ? 0 : 0.18 }}
      >
        <div className='rin-auth-dialog__head'>
          <h2 id='rin-auth-dialog-title'>
            {intl.formatMessage(messages.authTitle)}
          </h2>
          <AnimateButton
            unstyled
            type='button'
            aria-label={intl.formatMessage(messages.authClose)}
            disabled={busy}
            onClick={onClose}
          >
            ×
          </AnimateButton>
        </div>
        <form className='rin-auth-dialog__form' onSubmit={handleSubmit}>
          <label>
            <span>{intl.formatMessage(messages.authPhone)}</span>
            <input
              ref={phoneInput}
              type='tel'
              inputMode='tel'
              autoComplete='tel'
              value={phone}
              disabled={Boolean(challenge) || busy}
              placeholder={intl.formatMessage(messages.authPhonePlaceholder)}
              onChange={(event) => {
                setPhone(event.currentTarget.value);
              }}
            />
          </label>
          {challenge ? (
            <label>
              <span>{intl.formatMessage(messages.authCode)}</span>
              <input
                type='text'
                inputMode='numeric'
                autoComplete='one-time-code'
                value={code}
                disabled={busy}
                placeholder={intl.formatMessage(messages.authCodePlaceholder)}
                onChange={(event) => {
                  setCode(event.currentTarget.value);
                }}
              />
            </label>
          ) : null}
          {error ? (
            <p className='rin-auth-dialog__error' role='alert'>
              {error}
            </p>
          ) : null}
          {status ? (
            <p className='rin-auth-dialog__status' role='status'>
              {status}
            </p>
          ) : null}
          <div className='rin-auth-dialog__actions'>
            {challenge ? (
              <AnimateButton
                unstyled
                type='button'
                className='rin-auth-dialog__link'
                disabled={busy}
                onClick={() => {
                  setChallenge(null);
                  setCode('');
                  setStatus('');
                  setError('');
                }}
              >
                {intl.formatMessage(messages.authChangePhone)}
              </AnimateButton>
            ) : null}
            <AnimateButton unstyled type='submit' disabled={busy}>
              {busy
                ? intl.formatMessage(messages.authProcessing)
                : intl.formatMessage(
                    challenge ? messages.authComplete : messages.authSend,
                  )}
            </AnimateButton>
          </div>
        </form>
      </motion.section>
    </motion.div>,
    document.body,
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
    const recovery = new URLSearchParams(location.search).get(
      'rinspace_login',
    );
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
    () => recoveredReturnHref(location.pathname, location.search, location.hash),
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
      <header
        className='topbar rin-topbar-shell'
        data-session-state={signedIn ? 'authenticated' : 'anonymous'}
      >
        <span className='brand'>
          <motion.a
            className='brand-mark'
            href='/'
            aria-label={intl.formatMessage(messages.flip)}
            whileHover={reducedMotion ? undefined : { rotateY: 360 }}
            transition={{ type: 'spring', stiffness: 260, damping: 20 }}
            style={{ transformPerspective: 600 }}
          >
            {customAppIcon ? (
              <img
                src={customAppIcon}
                alt=''
                width='128'
                height='128'
                draggable={false}
              />
            ) : (
              <span className='brand-mark-fallback' aria-hidden='true'>
                R
              </span>
            )}
          </motion.a>
          <a
            className='brand-word'
            href='/?world=inner'
            aria-label={intl.formatMessage(messages.home)}
          >
            <SplittingText
              className='brand-word-motion'
              text={intl.formatMessage(messages.brandName)}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.35, ease: 'easeOut' }}
              stagger={0.04}
              disableAnimation={Boolean(reducedMotion)}
            />
          </a>
        </span>

        <Search singleColumn topbar />

        <nav
          className='account-nav'
          aria-label={intl.formatMessage(messages.navigation)}
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
                <CompassIcon size={18} />
              </motion.a>
              <motion.a
                className='topbar-pill'
                href={innerHref('/publish', '', '')}
                aria-label={intl.formatMessage(messages.publish)}
                title={intl.formatMessage(messages.publish)}
                whileHover={reducedMotion ? undefined : { y: -1 }}
                whileTap={reducedMotion ? undefined : { scale: 0.94 }}
              >
                <PlusIcon size={18} />
              </motion.a>
              <motion.a
                className='notification-pill'
                href={innerHref('/notifications', '', '')}
                aria-label={intl.formatMessage(messages.notifications)}
                title={intl.formatMessage(messages.notifications)}
                whileHover={reducedMotion ? undefined : { y: -1 }}
                whileTap={reducedMotion ? undefined : { scale: 0.94 }}
              >
                <BellIcon size={18} />
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
                  <GaugeIcon size={18} />
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
                    <CaretDownIcon size={16} aria-hidden='true' />
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
                      <UserIcon size={16} />
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
                      <GearIcon size={16} />
                      {intl.formatMessage(messages.preferences)}
                    </a>
                    <button
                      type='button'
                      role='menuitem'
                      onClick={submitSignOut}
                    >
                      <SignOutIcon size={16} />
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
        </nav>
      </header>
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
