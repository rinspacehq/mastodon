import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import test from 'node:test';

import { MAX_PARENT_LEASE_MS, RinspaceParentAuthorizationError, RinspaceParentAuthorizer } from './rinspace_parent_authorization.js';

const parent = { issuer: 'https://rinspace.example', uid: 'uid-7', sid: 'ad61074e-4f0f-4abe-b67b-056c939b57c5', version: '7' };

test('signs and verifies a managed browser parent at connection time', async () => {
  let request;
  const authorizer = new RinspaceParentAuthorizer({
    baseUrl: 'https://identity.internal',
    serviceId: 'mastodon-streaming',
    audience: 'mastodon',
    secret: 'test-only-secret',
    now: () => 1789200000000,
    nonce: () => 'nonce-1',
    fetchFn: async (url, options) => {
      request = { url, options };
      return { ok: true, json: async () => ({ active: true, currentVersion: 7 }) };
    },
  });

  await authorizer.assertActive(parent);

  const bodyHash = crypto.createHash('sha256').update(request.options.body).digest('hex');
  const canonical = ['POST', `/internal/v1/identity/sessions/${parent.sid}/status`, '1789200000', 'nonce-1', bodyHash].join('\n');
  const expected = crypto.createHmac('sha256', 'test-only-secret').update(canonical).digest('hex');
  assert.equal(request.options.headers['x-rin-signature'], expected);
  assert.deepEqual(JSON.parse(request.options.body), { sid: parent.sid, uid: parent.uid, issuedVersion: 7, audience: 'mastodon' });
});

test('fails closed for an inactive, stale, unavailable, or unconfigured parent', async () => {
  const cases = [
    async () => ({ ok: true, json: async () => ({ active: false, currentVersion: 7 }) }),
    async () => ({ ok: true, json: async () => ({ active: true, currentVersion: 6 }) }),
    async () => ({ ok: false, status: 503 }),
    async () => { throw new Error('offline'); },
  ];

  for (const fetchFn of cases) {
    const authorizer = new RinspaceParentAuthorizer({ baseUrl: 'https://identity.internal', serviceId: 'stream', audience: 'mastodon', secret: 'secret', fetchFn });
    await assert.rejects(authorizer.assertActive(parent), RinspaceParentAuthorizationError);
  }

  const unconfigured = new RinspaceParentAuthorizer({});
  await assert.rejects(unconfigured.assertActive(parent), RinspaceParentAuthorizationError);
  await assert.doesNotReject(unconfigured.assertActive(null));
});

test('closes only the invalid managed connection within its bounded lease', async () => {
  let checks = 0;
  let closed = 0;
  const authorizer = new RinspaceParentAuthorizer({
    baseUrl: 'https://identity.internal',
    serviceId: 'stream',
    audience: 'mastodon',
    secret: 'secret',
    fetchFn: async () => {
      checks += 1;
      return { ok: true, json: async () => ({ active: checks < 2, currentVersion: 7 }) };
    },
  });

  const stop = authorizer.startLease(parent, async () => { closed += 1; }, 5);
  await new Promise(resolve => setTimeout(resolve, 30));
  stop();

  assert.equal(closed, 1);
  assert.ok(checks >= 2);
  assert.equal(MAX_PARENT_LEASE_MS, 15000);
});
