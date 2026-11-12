import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { readFile, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
import { AvaliacaoFotoStorageService } from '../dist/avaliacoes/avaliacao-foto-storage.service.js';
import { DocumentoStorageService } from '../dist/verificacao/documento-storage.service.js';

test('document storage saves, reads, and removes local private files', async () => {
  const previousCwd = process.cwd();
  const previousDriver = process.env.FILE_STORAGE_DRIVER;
  const previousNodeEnv = process.env.NODE_ENV;
  const dir = await mkdtemp(join(tmpdir(), 'conectalar-storage-'));

  try {
    process.chdir(dir);
    delete process.env.FILE_STORAGE_DRIVER;
    process.env.NODE_ENV = 'development';
    const storage = new DocumentoStorageService();

    const referencia = await storage.salvar(
      10,
      Buffer.from('%PDF- teste'),
      'application/pdf',
    );
    assert.match(referencia, /^storage\/documentos-verificacao\/10\/.+\.pdf$/);

    const arquivo = await storage.carregar(1, referencia, 'documento.pdf');
    assert.equal(arquivo.mimeType, 'application/pdf');
    assert.equal(arquivo.nomeSeguro, 'documento.pdf');
    assert.equal(arquivo.bytes.toString('utf8'), '%PDF- teste');

    await storage.remover(referencia);
    await assert.rejects(
      () => storage.carregar(1, referencia, 'documento.pdf'),
      (error) =>
        error?.getResponse?.().code === 'ARQUIVO_DOCUMENTO_INDISPONIVEL',
    );
  } finally {
    restoreEnv('FILE_STORAGE_DRIVER', previousDriver);
    restoreEnv('NODE_ENV', previousNodeEnv);
    process.chdir(previousCwd);
    await rm(dir, { recursive: true, force: true });
  }
});

test('document storage requires R2 configuration by default in production', async () => {
  const previous = snapshotEnv([
    'NODE_ENV',
    'FILE_STORAGE_DRIVER',
    'R2_ACCOUNT_ID',
    'R2_BUCKET',
    'R2_ACCESS_KEY_ID',
    'R2_SECRET_ACCESS_KEY',
  ]);

  try {
    process.env.NODE_ENV = 'production';
    delete process.env.FILE_STORAGE_DRIVER;
    delete process.env.R2_ACCOUNT_ID;
    delete process.env.R2_BUCKET;
    delete process.env.R2_ACCESS_KEY_ID;
    delete process.env.R2_SECRET_ACCESS_KEY;

    const storage = new DocumentoStorageService();
    await assert.rejects(
      () => storage.salvar(10, Buffer.from('%PDF- teste'), 'application/pdf'),
      (error) =>
        error?.getResponse?.().code === 'ARQUIVO_DOCUMENTO_INDISPONIVEL',
    );
  } finally {
    restoreSnapshot(previous);
  }
});

test('production local storage uses an absolute persistent root outside the release', async () => {
  const previousCwd = process.cwd();
  const previous = snapshotEnv([
    'NODE_ENV',
    'FILE_STORAGE_DRIVER',
    'FILE_STORAGE_LOCAL_DIR',
  ]);
  const releaseDir = await mkdtemp(join(tmpdir(), 'conectalar-release-'));
  const persistentDir = await mkdtemp(join(tmpdir(), 'conectalar-persistent-'));

  try {
    process.chdir(releaseDir);
    process.env.NODE_ENV = 'production';
    process.env.FILE_STORAGE_DRIVER = 'local';
    process.env.FILE_STORAGE_LOCAL_DIR = persistentDir;

    const storage = new DocumentoStorageService();
    const reference = await storage.salvar(
      42,
      Buffer.from('%PDF- private test'),
      'application/pdf',
    );
    assert.match(reference, /^storage\/documentos-verificacao\/42\/.+\.pdf$/);
    const absolute = join(persistentDir, reference);
    assert.equal((await readFile(absolute)).toString(), '%PDF- private test');
    assert.equal((await stat(absolute)).isFile(), true);
    if (process.platform !== 'win32') {
      assert.equal((await stat(absolute)).mode & 0o777, 0o600);
      assert.equal((await stat(join(persistentDir, 'storage'))).mode & 0o777, 0o700);
    }

    const loaded = await storage.carregar(42, reference, null);
    assert.equal(loaded.bytes.toString(), '%PDF- private test');
    await storage.remover(reference);
    await assert.rejects(() => readFile(absolute), { code: 'ENOENT' });
  } finally {
    restoreSnapshot(previous);
    process.chdir(previousCwd);
    await rm(releaseDir, { recursive: true, force: true });
    await rm(persistentDir, { recursive: true, force: true });
  }
});

test('production local storage rejects missing, relative, or release-local roots', async () => {
  const previous = snapshotEnv([
    'NODE_ENV',
    'FILE_STORAGE_DRIVER',
    'FILE_STORAGE_LOCAL_DIR',
  ]);

  try {
    process.env.NODE_ENV = 'production';
    process.env.FILE_STORAGE_DRIVER = 'local';
    delete process.env.FILE_STORAGE_LOCAL_DIR;
    await assert.rejects(
      () => new DocumentoStorageService().salvar(10, Buffer.from('x'), 'application/pdf'),
      /FILE_STORAGE_LOCAL_DIR is required/,
    );

    process.env.FILE_STORAGE_LOCAL_DIR = 'relative/storage';
    await assert.rejects(
      () => new DocumentoStorageService().salvar(10, Buffer.from('x'), 'application/pdf'),
      /must be an absolute path/,
    );

    process.env.FILE_STORAGE_LOCAL_DIR = join(process.cwd(), 'private-files');
    await assert.rejects(
      () => new DocumentoStorageService().salvar(10, Buffer.from('x'), 'application/pdf'),
      /outside the application directory/,
    );
  } finally {
    restoreSnapshot(previous);
  }
});

test('evaluation photos use the same persistent local root', async () => {
  const previousCwd = process.cwd();
  const previous = snapshotEnv([
    'NODE_ENV',
    'FILE_STORAGE_DRIVER',
    'FILE_STORAGE_LOCAL_DIR',
  ]);
  const releaseDir = await mkdtemp(join(tmpdir(), 'conectalar-release-'));
  const persistentDir = await mkdtemp(join(tmpdir(), 'conectalar-persistent-'));

  try {
    process.chdir(releaseDir);
    process.env.NODE_ENV = 'production';
    process.env.FILE_STORAGE_DRIVER = 'local';
    process.env.FILE_STORAGE_LOCAL_DIR = persistentDir;

    const storage = new AvaliacaoFotoStorageService();
    const reference = storage.novaReferencia(75);
    const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
    await storage.salvar(reference, jpeg);
    assert.deepEqual(await storage.carregar(reference), jpeg);
    assert.equal((await stat(join(persistentDir, reference))).isFile(), true);
    await storage.remover(reference);
    await assert.rejects(() => readFile(join(persistentDir, reference)), { code: 'ENOENT' });
  } finally {
    restoreSnapshot(previous);
    process.chdir(previousCwd);
    await rm(releaseDir, { recursive: true, force: true });
    await rm(persistentDir, { recursive: true, force: true });
  }
});

test('R2 adapter uploads, reads, and deletes through an isolated S3 endpoint', async () => {
  const requests = [];
  const objectBytes = Buffer.from('private-r2-test-object');
  const server = createServer(async (request, response) => {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    requests.push({
      method: request.method,
      url: request.url,
      body: Buffer.concat(chunks),
      contentType: request.headers['content-type'],
    });

    if (request.method === 'GET') {
      response.writeHead(200, {
        'Content-Length': objectBytes.length,
        'Content-Type': 'image/jpeg',
      });
      response.end(objectBytes);
      return;
    }

    response.writeHead(200);
    response.end();
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });

  const address = server.address();
  assert.ok(address && typeof address === 'object');
  const previous = snapshotEnv([
    'NODE_ENV',
    'FILE_STORAGE_DRIVER',
    'R2_ACCOUNT_ID',
    'R2_BUCKET',
    'R2_ACCESS_KEY_ID',
    'R2_SECRET_ACCESS_KEY',
    'R2_ENDPOINT',
    'R2_REGION',
  ]);

  try {
    process.env.NODE_ENV = 'test';
    process.env.FILE_STORAGE_DRIVER = 'r2';
    process.env.R2_ACCOUNT_ID = 'local-test-account';
    process.env.R2_BUCKET = 'conectalar-test-only';
    process.env.R2_ACCESS_KEY_ID = 'local-test-access-key';
    process.env.R2_SECRET_ACCESS_KEY = 'local-test-secret-key';
    process.env.R2_ENDPOINT = `http://127.0.0.1:${address.port}`;
    process.env.R2_REGION = 'auto';

    const storage = new DocumentoStorageService();
    const referencia = await storage.salvar(
      23,
      Buffer.from('upload-body'),
      'image/jpeg',
    );
    assert.match(
      referencia,
      /^r2:\/\/documentos-verificacao\/23\/[0-9a-f-]+\.jpg$/,
    );

    const arquivo = await storage.carregar(23, referencia, 'prova.jpg');
    assert.equal(arquivo.bytes.toString(), objectBytes.toString());
    assert.equal(arquivo.mimeType, 'image/jpeg');
    assert.equal(arquivo.nomeSeguro, 'prova.jpg');
    await storage.remover(referencia);

    assert.deepEqual(
      requests.map(({ method }) => method),
      ['PUT', 'GET', 'DELETE'],
    );
    assert.ok(requests.every(({ url }) =>
      url.startsWith('/conectalar-test-only/documentos-verificacao/23/'),
    ));
    assert.equal(requests[0].body.toString(), 'upload-body');
    assert.equal(requests[0].contentType, 'image/jpeg');
  } finally {
    restoreSnapshot(previous);
    await new Promise((resolve, reject) =>
      server.close((error) => error ? reject(error) : resolve()),
    );
  }
});

function snapshotEnv(keys) {
  return Object.fromEntries(keys.map((key) => [key, process.env[key]]));
}

function restoreSnapshot(snapshot) {
  for (const [key, value] of Object.entries(snapshot)) {
    restoreEnv(key, value);
  }
}

function restoreEnv(key, value) {
  if (value === undefined) delete process.env[key];
  else process.env[key] = value;
}
