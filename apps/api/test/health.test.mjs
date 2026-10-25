import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createApp } from '../dist/app.factory.js';
import { ConfigurationError, loadConfig } from '../dist/config/environment.js';
import { HealthService } from '../dist/health/health.service.js';

let app;
let baseUrl;

before(async () => {
  app = await createApp();
  await app.listen(0, '127.0.0.1');
  const address = app.getHttpServer().address();
  assert.ok(address && typeof address === 'object');
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await app?.close();
});

test('health endpoint returns only the public status', async () => {
  const response = await fetch(`${baseUrl}/health`);

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(response.headers.get('x-frame-options'), 'DENY');
  assert.equal(response.headers.get('ratelimit-limit'), '120');
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('configuration rejects out-of-range ports without exposing their value', () => {
  const privateValue = '73119-secret';

  assert.throws(
    () => loadConfig({ NODE_ENV: 'test', PORT: privateValue }),
    (error) =>
      error instanceof ConfigurationError &&
      error.code === 'INVALID_PORT' &&
      !error.message.includes(privateValue),
  );
});

test('configuration rejects invalid trusted proxy hop counts', () => {
  for (const value of ['-1', '1.5', '11', '1,2']) {
    assert.throws(
      () => loadConfig({ NODE_ENV: 'test', TRUST_PROXY_HOPS: value }),
      (error) => error instanceof ConfigurationError &&
        error.code === 'INVALID_TRUST_PROXY_HOPS',
    );
  }
  assert.equal(loadConfig({ NODE_ENV: 'test' }).trustProxyHops, 0);
});

test('auth routes have stricter limits and cannot be bypassed with a forged X-Forwarded-For', async () => {
  const previous = {
    RATE_LIMIT_MAX: process.env.RATE_LIMIT_MAX,
    TRUST_PROXY_HOPS: process.env.TRUST_PROXY_HOPS,
  };
  process.env.RATE_LIMIT_MAX = '120';
  process.env.TRUST_PROXY_HOPS = '0';
  const limitedApp = await createApp();
  try {
    await limitedApp.listen(0, '127.0.0.1');
    const address = limitedApp.getHttpServer().address();
    assert.ok(address && typeof address === 'object');
    let lastResponse;
    for (let attempt = 0; attempt < 9; attempt++) {
      const slash = attempt % 2 === 0 ? '' : '/';
      lastResponse = await fetch(`http://127.0.0.1:${address.port}/auth/login${slash}`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-forwarded-for': `198.51.100.${attempt + 1}`,
        },
        body: '{}',
      });
    }
    assert.equal(lastResponse.status, 429);
    assert.equal(lastResponse.headers.get('ratelimit-limit'), '8');
    assert.ok(Number(lastResponse.headers.get('retry-after')) > 0);
  } finally {
    await limitedApp.close();
    if (previous.RATE_LIMIT_MAX === undefined) delete process.env.RATE_LIMIT_MAX;
    else process.env.RATE_LIMIT_MAX = previous.RATE_LIMIT_MAX;
    if (previous.TRUST_PROXY_HOPS === undefined) delete process.env.TRUST_PROXY_HOPS;
    else process.env.TRUST_PROXY_HOPS = previous.TRUST_PROXY_HOPS;
  }
});

test('liveness remains available while readiness rejects a missing runtime', async () => {
  const live = await fetch(`${baseUrl}/health/live`);
  assert.equal(live.status, 200);
  assert.deepEqual(await live.json(), { status: 'ok' });

  const ready = await fetch(`${baseUrl}/health/ready`);
  assert.equal(ready.status, 503);
  assert.deepEqual(await ready.json(), { status: 'not_ready' });
});

test('production rejects incomplete runtime configuration without exposing values', async () => {
  const complete = {
    NODE_ENV: 'production',
    DB_HOST: 'private-host',
    DB_USER: 'private-user',
    DB_NAME: 'private-database',
    AUTH_TOKEN_SECRET: 'private-auth-secret-at-least-thirty-two-characters',
    MFA_SECRET_ENCRYPTION_KEY: 'private-mfa-secret-at-least-thirty-two-characters',
    EMAIL_OUTBOX_ENCRYPTION_KEY: 'private-outbox-secret-at-least-thirty-two-chars',
    SMTP_HOST: 'smtp.example.invalid',
    SMTP_FROM: 'ConectaLar <mail@example.invalid>',
    SMTP_USER: 'smtp-user',
    SMTP_PASSWORD: 'smtp-password',
  };
  assert.equal(loadConfig(complete).nodeEnv, 'production');
  for (const key of [
    'DB_HOST', 'DB_USER', 'DB_NAME', 'AUTH_TOKEN_SECRET',
    'MFA_SECRET_ENCRYPTION_KEY', 'EMAIL_OUTBOX_ENCRYPTION_KEY',
    'SMTP_HOST', 'SMTP_FROM', 'SMTP_USER', 'SMTP_PASSWORD',
  ]) {
    for (const missing of [undefined, '', '   ']) {
      assert.throws(
        () => loadConfig({ ...complete, [key]: missing }),
        (error) => error instanceof ConfigurationError &&
          error.code === 'INCOMPLETE_PRODUCTION_RUNTIME' &&
          !error.message.includes('private-'),
      );
    }
  }
});

test('readiness checks MySQL and recovers after a failure without leaking errors', async () => {
  const previous = { ...process.env };
  try {
    Object.assign(process.env, {
      DB_HOST: '127.0.0.1', DB_USER: 'test', DB_NAME: 'test',
      AUTH_TOKEN_SECRET: 'local-test-secret-with-at-least-32-characters',
    });
    assert.equal(await new HealthService().isReady(), false);
    assert.equal(await new HealthService({ isInitialized: false }).isReady(), false);
    let fail = true;
    const service = new HealthService({
      isInitialized: true,
      async query(sql) {
        assert.equal(sql, 'SELECT 1');
        if (fail) throw new Error('private database password and hostname');
        return [{ 1: 1 }];
      },
    });
    assert.equal(await service.isReady(), false);
    fail = false;
    assert.equal(await service.isReady(), true);
  } finally {
    process.env = previous;
  }
});

test('a stalled MySQL probe times out and shares the outstanding query', async () => {
  const previous = { ...process.env };
  try {
    Object.assign(process.env, {
      DB_HOST: '127.0.0.1', DB_USER: 'test', DB_NAME: 'test',
      AUTH_TOKEN_SECRET: 'local-test-secret-with-at-least-32-characters',
    });
    let calls = 0;
    let resume;
    const service = new HealthService({
      isInitialized: true,
      query() {
        calls++;
        if (calls > 1) return Promise.resolve([{ 1: 1 }]);
        return new Promise((resolve) => { resume = resolve; });
      },
    });
    assert.deepEqual(await Promise.all([service.isReady(), service.isReady()]), [false, false]);
    assert.equal(calls, 1);
    resume([{ 1: 1 }]);
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(await service.isReady(), true);
  } finally {
    process.env = previous;
  }
});
