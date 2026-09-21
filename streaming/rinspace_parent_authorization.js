import crypto from 'node:crypto';

const DEFAULT_TIMEOUT_MS = 3000;
export const MAX_PARENT_LEASE_MS = 15000;

export class RinspaceParentAuthorizationError extends Error {}

export class RinspaceParentAuthorizer {
  constructor({ baseUrl, serviceId, audience, secret, fetchFn = fetch, now = Date.now, nonce = crypto.randomUUID, timeoutMs = DEFAULT_TIMEOUT_MS }) {
    this.baseUrl = baseUrl;
    this.serviceId = serviceId;
    this.audience = audience;
    this.secret = secret;
    this.fetchFn = fetchFn;
    this.now = now;
    this.nonce = nonce;
    this.timeoutMs = timeoutMs;
  }

  async assertActive(parent) {
    if (!parent) return;
    if (!this.baseUrl || !this.serviceId || !this.audience || !this.secret || !parent.uid || !parent.sid || !Number.isSafeInteger(Number(parent.version)) || Number(parent.version) < 1) {
      throw new RinspaceParentAuthorizationError('Rinspace parent authorization is not configured');
    }

    const body = JSON.stringify({
      sid: parent.sid,
      uid: parent.uid,
      issuedVersion: Number(parent.version),
      audience: this.audience,
    });
    const target = new URL(`/internal/v1/identity/sessions/${encodeURIComponent(parent.sid)}/status`, this.baseUrl);
    const timestamp = String(Math.floor(this.now() / 1000));
    const requestNonce = this.nonce();
    const bodyHash = crypto.createHash('sha256').update(body).digest('hex');
    const canonical = ['POST', `${target.pathname}${target.search}`, timestamp, requestNonce, bodyHash].join('\n');
    const signature = crypto.createHmac('sha256', this.secret).update(canonical).digest('hex');

    let response;
    try {
      response = await this.fetchFn(target, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-rin-service': this.serviceId,
          'x-rin-timestamp': timestamp,
          'x-rin-nonce': requestNonce,
          'x-rin-signature': signature,
        },
        body,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      throw new RinspaceParentAuthorizationError('Rinspace parent authorization is unavailable', { cause: error });
    }

    if (!response.ok) {
      throw new RinspaceParentAuthorizationError(`Rinspace parent authorization failed with ${response.status}`);
    }

    const result = await response.json();
    if (result.active !== true || Number(result.currentVersion) < Number(parent.version)) {
      throw new RinspaceParentAuthorizationError('Rinspace parent session is inactive');
    }
  }

  startLease(parent, onInvalid, intervalMs = MAX_PARENT_LEASE_MS) {
    if (!parent) return () => {};

    let stopped = false;
    const timer = setInterval(async () => {
      try {
        await this.assertActive(parent);
      } catch (error) {
        if (stopped) return;
        stopped = true;
        clearInterval(timer);
        await onInvalid(error);
      }
    }, Math.min(intervalMs, MAX_PARENT_LEASE_MS));

    return () => {
      stopped = true;
      clearInterval(timer);
    };
  }
}
