import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { test } from 'node:test';

test('R2 pilot script uses a dedicated bucket and cleans its unique object', async () => {
  const objects = new Map();
  const requests = [];
  const server = createServer(async (request, response) => {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    const body = Buffer.concat(chunks);
    const path = new URL(request.url, 'http://localhost').pathname;
    const key = path.replace(/^\/conectalar-piloto-test\//u, '');
    requests.push({ method: request.method, path, body });

    if (request.method === 'PUT') {
      objects.set(key, body);
      response.writeHead(200).end();
      return;
    }
    if (request.method === 'GET' && objects.has(key)) {
      const object = objects.get(key);
      response.writeHead(200, {
        'Content-Length': object.length,
        'Content-Type': 'text/plain; charset=utf-8',
      }).end(object);
      return;
    }
    if (request.method === 'DELETE') {
      objects.delete(key);
      response.writeHead(204).end();
      return;
    }
    response.writeHead(404).end();
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });

  try {
    const address = server.address();
    assert.ok(address && typeof address === 'object');
    const result = await runPilotScript(address.port);
    assert.equal(result.code, 0, `${result.stderr}\n${result.stdout}`);
    assert.match(result.stdout, /PUT, GET, content comparison, and DELETE succeeded/u);
    assert.deepEqual(requests.map(({ method }) => method), ['PUT', 'GET', 'DELETE']);
    assert.equal(objects.size, 0);
    assert.ok(requests.every(({ path }) =>
      path.startsWith('/conectalar-piloto-test/conectalar-r2-pilot/'),
    ));
    assert.ok(!result.stdout.includes('local-test-secret-key'));

    const insecureEndpoint = await runPilotScript(address.port, {
      R2_PILOT_ENDPOINT: 'http://203.0.113.5',
    });
    assert.notEqual(insecureEndpoint.code, 0);
    assert.match(insecureEndpoint.stderr, /must use HTTPS/u);
    assert.equal(requests.length, 3, 'insecure remote endpoint must not be contacted');
  } finally {
    await new Promise((resolve, reject) =>
      server.close((error) => error ? reject(error) : resolve()),
    );
  }
}, { timeout: 10_000 });

function runPilotScript(port, overrides = {}) {
  const child = spawn(process.execPath, ['scripts/test-r2-pilot.mjs'], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      R2_PILOT_ACCOUNT_ID: 'local-test-account',
      R2_PILOT_BUCKET: 'conectalar-piloto-test',
      R2_PILOT_CONFIRM_BUCKET: 'conectalar-piloto-test',
      R2_PILOT_ACCESS_KEY_ID: 'local-test-access-key',
      R2_PILOT_SECRET_ACCESS_KEY: 'local-test-secret-key',
      R2_PILOT_ENDPOINT: `http://127.0.0.1:${port}`,
      ...overrides,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let stdout = '';
  let stderr = '';
  child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk; });
  child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });

  return new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code) => resolve({ code, stdout, stderr }));
  });
}
