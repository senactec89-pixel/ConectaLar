import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { test } from 'node:test';
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
