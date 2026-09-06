import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  completeRinspacePhoneOtp,
  getFreshRinspaceSession,
  getRinspaceSession,
  sendRinspacePhoneOtp,
  startRinspaceSso,
} from './rinspace_auth';

vi.mock('mastodon/initial_state', () => ({
  rinspaceAuth: {
    client_id: 'rin-test',
    gateway: 'https://rin-test.example/auth/v1',
    sso_prepare_path: '/auth/rinspace',
  },
}));

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

describe('Rinspace browser authentication adapter', () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
    document.head.innerHTML = '';
    document.body.innerHTML = '';
    vi.restoreAllMocks();
  });

  it('uses the same public gateway, client and device semantics as the outer UI', async () => {
    const fetchMock = vi
      .spyOn(window, 'fetch')
      .mockResolvedValue(response({ verification_id: 'verification-1', is_user: true }));

    const challenge = await sendRinspacePhoneOtp('13800138000');

    expect(challenge).toEqual({
      verificationId: 'verification-1',
      phoneNumber: '+86 13800138000',
      isUser: true,
    });
    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(url).toBe('https://rin-test.example/auth/v1/verification?client_id=rin-test');
    expect((init?.headers as Record<string, string>)['x-device-id']).toBeTruthy();
    expect(window.localStorage.getItem('rinspace-device-id')).toBeTruthy();
  });

  it('persists the outer session only after verification and sign-in succeed', async () => {
    vi.spyOn(window, 'fetch')
      .mockResolvedValueOnce(response({ verification_token: 'verified' }))
      .mockResolvedValueOnce(
        response({
          access_token: 'access-token',
          refresh_token: 'refresh-token',
          expires_in: 3600,
          sub: 'subject-1',
        }),
      );

    await completeRinspacePhoneOtp(
      {
        verificationId: 'verification-1',
        phoneNumber: '+86 13800138000',
        isUser: true,
      },
      '123456',
    );

    expect(getRinspaceSession()).toMatchObject({
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      sub: 'subject-1',
    });
  });

  it('preserves the shared outer session after a transient refresh failure', async () => {
    window.localStorage.setItem(
      'rinspace-auth-session',
      JSON.stringify({
        access_token: 'expired-access',
        refresh_token: 'refresh-token',
        expires_in: 1,
        issued_at: Date.now() - 60_000,
      }),
    );
    vi.spyOn(window, 'fetch').mockRejectedValue(new TypeError('offline'));

    await expect(getFreshRinspaceSession()).rejects.toThrow('offline');
    expect(getRinspaceSession()?.refresh_token).toBe('refresh-token');
  });

  it('clears the shared session only after a definitive refresh rejection', async () => {
    window.localStorage.setItem(
      'rinspace-auth-session',
      JSON.stringify({
        access_token: 'expired-access',
        refresh_token: 'revoked-token',
        expires_in: 1,
        issued_at: Date.now() - 60_000,
      }),
    );
    vi.spyOn(window, 'fetch').mockResolvedValue(
      response({ error: 'invalid_grant' }, 401),
    );

    await expect(getFreshRinspaceSession()).rejects.toThrow('invalid_grant');
    expect(getRinspaceSession()).toBeNull();
  });

  it('posts the exact return target through the CSRF-protected preparation route', () => {
    document.head.innerHTML = `
      <meta name="csrf-param" content="authenticity_token">
      <meta name="csrf-token" content="csrf-value">
    `;
    const requestSubmit = vi
      .spyOn(HTMLFormElement.prototype, 'requestSubmit')
      .mockImplementation(() => undefined);

    startRinspaceSso('/search?q=reverse+engineering&world=inner#results');

    expect(requestSubmit).toHaveBeenCalledOnce();
    const form = document.querySelector<HTMLFormElement>('form');
    expect(form?.getAttribute('action')).toBe('/auth/rinspace');
    expect(
      form?.querySelector<HTMLInputElement>('input[name="return_to"]')?.value,
    ).toBe('/search?q=reverse+engineering&world=inner#results');
    expect(
      form?.querySelector<HTMLInputElement>('input[name="authenticity_token"]')
        ?.value,
    ).toBe('csrf-value');
  });
});
