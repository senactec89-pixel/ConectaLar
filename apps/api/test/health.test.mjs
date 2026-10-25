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
