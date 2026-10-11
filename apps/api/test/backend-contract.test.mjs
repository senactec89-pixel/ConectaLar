import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { databaseRuntimeOptions } from '../dist/database/database.config.js';

const source = (path) =>
  readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('service requests protect full client address by role and status', async () => {
  const solicitacoes = await source(
    'dist/solicitacoes/solicitacoes.service.js',
  );

  assert.match(solicitacoes, /enderecoProtegido/);
  assert.match(solicitacoes, /enderecoCompletoLiberado/);
  assert.match(solicitacoes, /AceitaAgendada/);
  assert.match(solicitacoes, /ConclusaoConfirmada/);
  assert.match(solicitacoes, /ENDERECO_INVALIDO/);
});

test('sensitive administrative actions are auditable', async () => {
  const actions = await source('dist/domain/admin-auditoria-acao.js');
  const painel = await source('dist/admin-painel/admin-painel.controller.js');

  for (const action of [
    'categoria_criada',
    'categoria_atualizada',
    'documento_analisado',
    'denuncia_moderada',
    'avaliacao_moderada',
  ]) {
    assert.match(actions, new RegExp(action));
  }
  assert.match(painel, /auditoria/);
});

test('backend contract documents logout, agenda, protected address, and audit', async () => {
  const openapi = await readFile(
    new URL('../openapi.yaml', import.meta.url),
    'utf8',
  );

  assert.match(openapi, /\/auth\/logout:/);
  assert.match(openapi, /\/profissionais\/me\/agenda:/);
  assert.match(openapi, /\/profissionais\/me\/documentos:/);
  assert.match(openapi, /\/admin\/painel\/auditoria:/);
  assert.match(openapi, /enderecoProtegido/);
  assert.match(openapi, /enderecoAtendimento/);
  assert.match(openapi, /\/profissionais\/me\/avaliacoes:/);
  assert.match(openapi, /\/profissionais\/\{id\}\/avaliacoes:/);
  assert.match(openapi, /servicoId/);
  assert.match(openapi, /nomeServico/);
});

test('civil dates remain strings while timestamps keep their timezone', () => {
  const previous = {
    DB_HOST: process.env.DB_HOST,
    DB_USER: process.env.DB_USER,
    DB_NAME: process.env.DB_NAME,
  };
  try {
    process.env.DB_HOST = '127.0.0.1';
    process.env.DB_USER = 'test';
    process.env.DB_NAME = 'conectalar_test';
    const options = databaseRuntimeOptions();
    assert.deepEqual(options.dateStrings, ['DATE']);
    assert.equal(options.timezone, 'Z');
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('verification upload keeps files private and validates size and type', async () => {
  const verificacao = await source('dist/verificacao/verificacao.service.js');

  assert.match(verificacao, /maxDocumentoBytes/);
  assert.match(verificacao, /application\/pdf/);
  assert.match(verificacao, /image\/jpeg/);
  assert.match(verificacao, /image\/png/);
  assert.match(verificacao, /storage/);
  assert.doesNotMatch(verificacao, /http:\/\/|https:\/\//);
});
