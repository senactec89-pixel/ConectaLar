import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createApp } from '../dist/app.factory.js';
import { ConfigurationError, loadConfig } from '../dist/config/environment.js';

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
