import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { normalizarNomeServico, opcoesPropostas } from '../scripts/catalogo-opcoes-propostas.mjs';

test('cada servico proposto tem cinco opcoes distintas para o profissional', async () => {
  const servicos = JSON.parse(await readFile(new URL('../scripts/catalogo-proposto.json', import.meta.url), 'utf8'));

  assert.equal(servicos.length, 37);
  assert.equal(opcoesPropostas.size, servicos.length);
  for (const servico of servicos) {
    const opcoes = opcoesPropostas.get(normalizarNomeServico(servico.nome));
    assert.equal(opcoes?.length, 5, `${servico.nome} deve ter cinco opcoes`);
    assert.equal(new Set(opcoes.map(normalizarNomeServico)).size, 5, `${servico.nome} nao deve repetir opcoes`);
    assert.ok(opcoes.every((opcao) => opcao.trim().length >= 2 && opcao.length <= 120));
  }
});
