const recoveryPath = '/auth/rinspace/recover';

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
