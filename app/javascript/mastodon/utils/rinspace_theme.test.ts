import { runInNewContext } from 'node:vm';

import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';

import inlineScript from '../../inline/theme-selection?raw';

import { setRinspaceTheme } from './rinspace_theme';

describe('shared Rinspace browser theme', () => {
  let dark = false;
  let media: EventTarget;
  let listeners: [string, EventListener][];
  const bootstrap = () => {
    const facade = {
      get localStorage() { return window.localStorage; },
      matchMedia: window.matchMedia.bind(window),
      addEventListener(name: string, listener: EventListener) {
        listeners.push([name, listener]);
        window.addEventListener(name, listener);
      },
    };
    runInNewContext(inlineScript, { window: facade, document });
  };
  beforeEach(() => {
    localStorage.clear();
    dark = false;
    media = new EventTarget();
    listeners = [];
    Object.defineProperty(window, 'matchMedia', {
      configurable: true,
      value: vi.fn((query: string) => ({
        media: query,
        get matches() {
          return dark;
        },
        onchange: null,
        addEventListener: media.addEventListener.bind(media),
        removeEventListener: media.removeEventListener.bind(media),
        addListener: vi.fn(),
        removeListener: vi.fn(),
        dispatchEvent: media.dispatchEvent.bind(media),
      })),
    });
  });
  afterEach(() => {
    listeners.forEach(([name, listener]) => {
      window.removeEventListener(name, listener);
    });
    vi.restoreAllMocks();
  });

  it('uses system by default, migrates legacy, and prioritizes shared preferences', () => {
    bootstrap();
    expect(document.documentElement.dataset.systemTheme).toBe('true');
    localStorage.setItem('rinspace-inner-color-scheme', 'dark');
    window.dispatchEvent(new Event('focus'));
    expect(document.documentElement.dataset.colorScheme).toBe('dark');
    expect(localStorage.getItem('rinspace-theme-v2')).toBe('dark');
    localStorage.setItem('rinspace-theme-v2', 'system');
    window.dispatchEvent(new Event('focus'));
    expect(document.documentElement.dataset.systemTheme).toBe('true');
  });

  it('publishes the shared key and does not revert explicit choices on OS changes', () => {
    bootstrap();
    setRinspaceTheme('dark');
    expect(localStorage.getItem('rinspace-theme-v2')).toBe('dark');
    media.dispatchEvent(new Event('change'));
    expect(document.documentElement.dataset.colorScheme).toBe('dark');
    setRinspaceTheme('system');
    expect(document.documentElement.dataset.colorScheme).toBe('light');
    dark = true;
    media.dispatchEvent(new Event('change'));
    expect(document.documentElement.dataset.colorScheme).toBe('dark');
    expect(document.documentElement.dataset.systemTheme).toBe('true');
  });

  it('refreshes on storage, focus and pageshow', () => {
    bootstrap();
    for (const event of [
      new StorageEvent('storage', { key: 'rinspace-theme-v2' }),
      new Event('focus'),
      new Event('pageshow'),
    ]) {
      localStorage.setItem('rinspace-theme-v2', 'dark');
      window.dispatchEvent(event);
      expect(document.documentElement.dataset.colorScheme).toBe('dark');
      setRinspaceTheme('light');
    }
  });

  it('renders and toggles despite unavailable storage', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new DOMException('Denied', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('Full', 'QuotaExceededError');
    });
    bootstrap();
    expect(document.documentElement.dataset.colorScheme).toBe('light');
    setRinspaceTheme('dark');
    window.dispatchEvent(new Event('focus'));
    expect(document.documentElement.dataset.colorScheme).toBe('dark');
  });
});
