(function (element) {
  const {contrast} = element.dataset;
  const storageKey = 'rinspace-theme-v2';
  let sessionPreference;
  const isPreference = value => value === 'light' || value === 'dark' || value === 'system';
  const readPreference = () => {
    if (sessionPreference) return sessionPreference;
    try {
      const stored = window.localStorage.getItem(storageKey);
      if (isPreference(stored)) return stored;
      const legacy = window.localStorage.getItem('rinspace-inner-color-scheme');
      if (legacy === 'light' || legacy === 'dark') {
        try { window.localStorage.setItem(storageKey, legacy); } catch { sessionPreference = legacy; }
        return legacy;
      }
    } catch { /* Storage is optional for rendering. */ }
    return 'system';
  };
  const colorSchemeMediaWatcher = window.matchMedia('(prefers-color-scheme: dark)');
  const updateColorScheme = () => {
    const preference = readPreference();
    const resolved = preference === 'system'
      ? colorSchemeMediaWatcher.matches ? 'dark' : 'light' : preference;
    element.dataset.colorScheme = resolved;
    element.dataset.systemTheme = String(preference === 'system');
    element.style.colorScheme = resolved;
    document.querySelectorAll('meta[name="theme-color"]').forEach(meta => {
      meta.setAttribute('content', resolved === 'dark' ? '#0b1218' : '#f8fafc');
    });
  };
  const contrastMediaWatcher = window.matchMedia('(prefers-contrast: more)');

  const updateContrast = () => {
    const useHighContrast = contrast === 'high' || contrastMediaWatcher.matches;

    element.dataset.contrast = useHighContrast ? 'high' : 'default';
  }

  colorSchemeMediaWatcher.addEventListener('change', updateColorScheme);
  window.addEventListener('storage', event => {
    if (event.key !== storageKey && event.key !== null) return;
    sessionPreference = undefined;
    updateColorScheme();
  });
  window.addEventListener('rinspace-theme-changed', event => {
    const detail = event.detail;
    if (!detail || !isPreference(detail.preference)) return;
    sessionPreference = detail.persisted ? undefined : detail.preference;
    updateColorScheme();
  });
  window.addEventListener('pageshow', updateColorScheme);
  window.addEventListener('focus', updateColorScheme);
  contrastMediaWatcher.addEventListener('change', updateContrast);

  updateColorScheme();
  updateContrast();

  let isRedesignEnabled = false;
  try {
    isRedesignEnabled = (window.localStorage.getItem('experiments')?.split(',') ?? []).includes('redesign');
  } catch { /* A restricted browser must still initialize its theme. */ }

  if (isRedesignEnabled) {
    element.dataset.redesign = true;
  }

})(document.documentElement);
