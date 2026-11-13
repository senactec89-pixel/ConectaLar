import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

test('lista proposta preserva as categorias e os servicos decididos', async () => {
  const itens = JSON.parse(await readFile(new URL('../scripts/catalogo-proposto.json', import.meta.url), 'utf8'));
  assert.equal(itens.length, 37);
  assert.equal(new Set(itens.map((item) => `${item.categoria}/${item.nome}`)).size, itens.length);
  assert.ok(itens.every((item) => item.nome.length <= 90 && !('ativo' in item)));
  assert.ok(itens.every((item) => ['descricao', 'inclusoes', 'exclusoes'].every((field) =>
    typeof item[field] === 'string' && item[field].trim().length > 0 && item[field].length <= 1000)));
  const contagem = Object.groupBy(itens, (item) => item.categoria);
  for (const categoria of ['Limpeza', 'Pintura', 'Manutencao', 'Eletrica', 'Hidraulica']) {
    assert.ok((contagem[categoria]?.length ?? 0) >= 5, `${categoria} precisa de pelo menos cinco servicos`);
  }
  assert.ok(itens.some((item) => item.categoria === 'Manutencao' && item.nome === 'Montagem de cadeira'));
  assert.ok(itens.some((item) => item.categoria === 'Limpeza' && item.nome === 'Limpeza residencial padrao' && item.inclusoes.toLowerCase().includes('cozinha e banheiro')));
  assert.ok(!itens.some((item) => ['Limpeza de cozinha', 'Limpeza de banheiro'].includes(item.nome)));
});
