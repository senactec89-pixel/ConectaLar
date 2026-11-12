import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

test('lista proposta preserva as categorias e os servicos decididos', async () => {
  const itens = JSON.parse(await readFile(new URL('../scripts/catalogo-proposto.json', import.meta.url), 'utf8'));
  assert.equal(itens.length, 37);
  assert.equal(new Set(itens.map((item) => `${item.categoria}/${item.nome}`)).size, itens.length);
  assert.ok(itens.every((item) => item.nome.length <= 90 && !('ativo' in item)));
  assert.ok(itens.some((item) => item.categoria === 'Manutencao' && item.nome === 'Montagem de cadeira'));
  assert.ok(itens.some((item) => item.categoria === 'Limpeza' && item.nome === 'Limpeza residencial padrao' && item.descricao.includes('cozinha e banheiro')));
  assert.ok(!itens.some((item) => ['Limpeza de cozinha', 'Limpeza de banheiro'].includes(item.nome)));
});
