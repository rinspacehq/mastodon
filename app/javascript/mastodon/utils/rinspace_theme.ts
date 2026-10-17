export type RinspaceThemePreference = 'light' | 'dark' | 'system';

/** The pre-paint inline script owns subscriptions; controls only publish. */
export function setRinspaceTheme(preference: RinspaceThemePreference) {
  let persisted = false;
  try {
    localStorage.setItem('rinspace-theme-v2', preference);
    persisted = true;
  } catch {
    /* An explicit choice can still work for this document. */
  }
  const resolved =
    preference === 'system'
      ? window.matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark'
        : 'light'
      : preference;
  const root = document.documentElement;
  root.dataset.colorScheme = resolved;
  root.dataset.systemTheme = String(preference === 'system');
  root.style.colorScheme = resolved;
  document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => {
    meta.setAttribute('content', resolved === 'dark' ? '#0b1218' : '#f8fafc');
  });
  window.dispatchEvent(
    new CustomEvent('rinspace-theme-changed', {
      detail: { preference, persisted },
    }),
  );
}
