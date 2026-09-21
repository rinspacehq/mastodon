const recoveryPath = '/auth/rinspace/recover';
export const RINSPACE_LOGIN_REQUEST_EVENT = 'rinspace:login-request';

export function usesRinspaceLogin(
  configuredRedirect: string | null | undefined,
) {
  return configuredRedirect === recoveryPath;
}

export function requestRinspaceLogin(
  configuredRedirect: string | null | undefined,
) {
  if (!usesRinspaceLogin(configuredRedirect)) return false;

  const request = new Event(RINSPACE_LOGIN_REQUEST_EVENT, {
    cancelable: true,
  });
  window.dispatchEvent(request);
  if (!request.defaultPrevented) {
    window.location.assign(rinspaceLoginHref(configuredRedirect));
  }
  return true;
}

export function handleRinspaceLoginClick(
  event: Pick<Event, 'preventDefault'>,
  configuredRedirect: string | null | undefined,
) {
  if (!requestRinspaceLogin(configuredRedirect)) return;
  event.preventDefault();
}

export function rinspaceLoginHref(
  configuredRedirect: string | null | undefined,
) {
  const target = configuredRedirect ?? '/auth/sign_in';
  if (target !== recoveryPath) return target;

  const current = new URL(window.location.href);
  current.searchParams.delete('rinspace_login');
  current.searchParams.delete('rinspace_return_to');
  if (!current.pathname.startsWith('/p/')) {
    current.searchParams.set('world', 'inner');
  }
  const returnTo = `${current.pathname}${current.search}${current.hash === '#login' ? '' : current.hash}`;
  return `${recoveryPath}?return_to=${encodeURIComponent(returnTo)}`;
}

export function rinspaceLoginMethod(
  configuredRedirect: string | null | undefined,
) {
  return configuredRedirect && configuredRedirect !== recoveryPath
    ? 'post'
    : undefined;
}
