import { rinspaceAuth } from 'mastodon/initial_state';

const sessionKey = 'rinspace-auth-session';
const sessionFallbackKey = 'rinspace-auth-session-fallback';
const deviceKey = 'rinspace-device-id';
const deviceFallbackKey = 'rinspace-device-id-fallback';
const timeoutMs = 8_000;
const refreshWindowMs = 60_000;
let inMemoryDeviceId = '';
let refreshRequest: {
  refreshToken: string;
  request: Promise<RinspaceSession | null>;
} | null = null;

export interface RinspaceSession {
  access_token: string;
  refresh_token: string;
  expires_in?: number;
  issued_at?: number;
  sub?: string;
}

export interface RinspaceOtpChallenge {
  verificationId: string;
  phoneNumber: string;
  isUser: boolean;
}

interface AuthPayload {
  verification_id?: string;
  verification_token?: string;
  is_user?: boolean;
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  sub?: string;
  error?: string;
  error_description?: string;
  code?: string;
  message?: string;
}

export class RinspaceAuthError extends Error {
  constructor(
    public readonly code: 'unavailable' | 'timeout' | 'request' | 'storage',
    message: string,
    public readonly status?: number,
    public readonly payload?: AuthPayload,
  ) {
    super(message);
    this.name = 'RinspaceAuthError';
  }
}

function read(storage: Storage, key: string) {
  try {
    return storage.getItem(key);
  } catch {
    return null;
  }
}

function write(storage: Storage, key: string, value: string) {
  try {
    storage.setItem(key, value);
    return true;
  } catch {
    return false;
  }
}

function remove(storage: Storage, key: string) {
  try {
    storage.removeItem(key);
  } catch {
    // Storage can be unavailable in privacy modes. Session fallback remains usable.
  }
}

function createDeviceId() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  return `device-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

function getDeviceId() {
  const existing =
    read(window.localStorage, deviceKey) ??
    read(window.sessionStorage, deviceFallbackKey);
  if (existing) return existing;
  if (inMemoryDeviceId) return inMemoryDeviceId;

  const next = createDeviceId();
  if (
    !write(window.localStorage, deviceKey, next) &&
    !write(window.sessionStorage, deviceFallbackKey, next)
  ) {
    inMemoryDeviceId = next;
  }
  return next;
}

function saveSession(session: RinspaceSession) {
  const value = JSON.stringify({ ...session, issued_at: Date.now() });
  remove(window.sessionStorage, sessionFallbackKey);
  if (
    !write(window.localStorage, sessionKey, value) &&
    !write(window.sessionStorage, sessionFallbackKey, value)
  ) {
    throw new RinspaceAuthError('storage', 'session_storage_unavailable');
  }
}

export function clearRinspaceSession() {
  remove(window.localStorage, sessionKey);
  remove(window.sessionStorage, sessionFallbackKey);
}

export function getRinspaceSession(): RinspaceSession | null {
  const value =
    read(window.localStorage, sessionKey) ??
    read(window.sessionStorage, sessionFallbackKey);
  if (!value) return null;

  try {
    const session = JSON.parse(value) as Partial<RinspaceSession>;
    if (
      typeof session.access_token === 'string' &&
      typeof session.refresh_token === 'string'
    ) {
      return session as RinspaceSession;
    }
  } catch {
    // Invalid session data must not be forwarded into OIDC.
  }

  clearRinspaceSession();
  return null;
}

function message(payload: AuthPayload, fallback: string) {
  return (
    payload.error_description ??
    payload.message ??
    payload.error ??
    payload.code ??
    fallback
  );
}

async function postAuth(path: string, body: Record<string, unknown>) {
  if (!rinspaceAuth?.client_id || !rinspaceAuth.gateway) {
    throw new RinspaceAuthError('unavailable', 'rinspace_auth_unavailable');
  }

  const controller = new AbortController();
  const timeout = window.setTimeout(() => {
    controller.abort();
  }, timeoutMs);
  try {
    const response = await fetch(
      `${rinspaceAuth.gateway}${path}?client_id=${encodeURIComponent(rinspaceAuth.client_id)}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-device-id': getDeviceId(),
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      },
    );
    const payload = (await response.json().catch(() => ({}))) as AuthPayload;
    if (!response.ok || payload.error || payload.code) {
      throw new RinspaceAuthError(
        'request',
        message(payload, 'rinspace_auth_request_failed'),
        response.status,
        payload,
      );
    }
    return payload;
  } catch (error) {
    if (controller.signal.aborted) {
      throw new RinspaceAuthError('timeout', 'rinspace_auth_timeout');
    }
    throw error;
  } finally {
    window.clearTimeout(timeout);
  }
}

function tokenExpiry(session: RinspaceSession) {
  const payload = session.access_token.split('.')[1];
  if (payload) {
    try {
      const normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
      const padded = normalized.padEnd(
        normalized.length + ((4 - (normalized.length % 4)) % 4),
        '=',
      );
      const claims = JSON.parse(window.atob(padded)) as { exp?: unknown };
      if (typeof claims.exp === 'number') return claims.exp * 1000;
    } catch {
      // Fall through to the issued_at/expires_in values.
    }
  }
  if (session.issued_at && session.expires_in) {
    return session.issued_at + session.expires_in * 1000;
  }
  return null;
}

export async function getFreshRinspaceSession() {
  const session = getRinspaceSession();
  if (!session) return null;
  const expiry = tokenExpiry(session);
  if (!expiry || expiry - Date.now() > refreshWindowMs) return session;

  if (refreshRequest?.refreshToken === session.refresh_token) {
    return refreshRequest.request;
  }

  const refreshToken = session.refresh_token;
  const request = (async () => {
    const payload = await postAuth('/token', {
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    });
    if (
      typeof payload.access_token !== 'string' ||
      typeof payload.refresh_token !== 'string'
    ) {
      throw new RinspaceAuthError('request', 'rinspace_auth_refresh_failed');
    }
    const refreshed: RinspaceSession = {
      access_token: payload.access_token,
      refresh_token: payload.refresh_token,
      expires_in: payload.expires_in,
      sub: payload.sub ?? session.sub,
    };
    saveSession(refreshed);
    return refreshed;
  })()
    .catch((error: unknown) => {
      if (isDefinitiveAuthFailure(error)) {
        const latest = getRinspaceSession();
        if (latest?.refresh_token === refreshToken) clearRinspaceSession();
      }
      throw error;
    })
    .finally(() => {
      if (refreshRequest?.request === request) refreshRequest = null;
    });
  refreshRequest = { refreshToken, request };
  return request;
}

function isDefinitiveAuthFailure(error: unknown) {
  if (!(error instanceof RinspaceAuthError)) return false;
  if (error.status === 401 || error.status === 403) return true;
  return ['unauthorized', 'UNAUTHENTICATED', 'INVALID_REFRESH_TOKEN', 'invalid_grant'].includes(
    error.payload?.error ?? error.payload?.code ?? '',
  );
}

export function normalizeMainlandPhone(value: string) {
  return value.replace(/^\+86\s*/, '').replace(/[\s-]/g, '');
}

export function isMainlandPhone(value: string) {
  return /^1\d{10}$/.test(normalizeMainlandPhone(value));
}

export async function sendRinspacePhoneOtp(
  phone: string,
): Promise<RinspaceOtpChallenge> {
  const phoneNumber = `+86 ${normalizeMainlandPhone(phone)}`;
  const payload = await postAuth('/verification', {
    phone_number: phoneNumber,
  });
  if (typeof payload.verification_id !== 'string') {
    throw new RinspaceAuthError('request', 'rinspace_auth_challenge_missing');
  }
  return {
    verificationId: payload.verification_id,
    phoneNumber,
    isUser: payload.is_user === true,
  };
}

export async function completeRinspacePhoneOtp(
  challenge: RinspaceOtpChallenge,
  code: string,
) {
  const verified = await postAuth('/verification/verify', {
    verification_id: challenge.verificationId,
    verification_code: code,
  });
  if (typeof verified.verification_token !== 'string') {
    throw new RinspaceAuthError(
      'request',
      'rinspace_auth_verification_missing',
    );
  }

  const session = challenge.isUser
    ? await postAuth('/signin', {
        verification_token: verified.verification_token,
      })
    : await postAuth('/signup', {
        phone_number: challenge.phoneNumber,
        verification_token: verified.verification_token,
      });
  if (
    typeof session.access_token !== 'string' ||
    typeof session.refresh_token !== 'string'
  ) {
    throw new RinspaceAuthError('request', 'rinspace_auth_session_missing');
  }

  saveSession({
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_in: session.expires_in,
    sub: session.sub,
  });
}

export function startRinspaceSso(returnTo: string) {
  if (!rinspaceAuth?.sso_prepare_path) {
    throw new RinspaceAuthError('unavailable', 'rinspace_sso_unavailable');
  }
  const csrfParam = document.querySelector<HTMLMetaElement>(
    'meta[name="csrf-param"]',
  );
  const csrfToken = document.querySelector<HTMLMetaElement>(
    'meta[name="csrf-token"]',
  );
  if (!csrfParam?.content || !csrfToken?.content) {
    throw new RinspaceAuthError('unavailable', 'rinspace_csrf_unavailable');
  }

  const form = document.createElement('form');
  form.method = 'post';
  form.action = rinspaceAuth.sso_prepare_path;
  form.hidden = true;
  const fields: [string, string][] = [
    [csrfParam.content, csrfToken.content],
    ['return_to', returnTo],
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
