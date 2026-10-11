import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('service requests protect full client address by role and status', async () => {
  const solicitacoes = await source('dist/solicitacoes/solicitacoes.service.js');

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
  const openapi = await readFile(new URL('../openapi.yaml', import.meta.url), 'utf8');

  assert.match(openapi, /\/auth\/logout:/);
  assert.match(openapi, /\/profissionais\/me\/agenda:/);
  assert.match(openapi, /\/admin\/painel\/auditoria:/);
  assert.match(openapi, /enderecoProtegido/);
  assert.match(openapi, /enderecoAtendimento/);
});
