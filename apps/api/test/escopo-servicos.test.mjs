import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';
import { snapshotEscopo } from '../dist/domain/escopo-servico.js';
import { EscopoOfertas1760138000000 } from '../dist/database/migrations/1760138000000-EscopoOfertas.js';

function fixture() {
  const oferta = { id: 1, nome: 'Limpeza', categoriaId: null, ativo: true,
    inclui: ['Pisos'], naoInclui: ['Altura'], opcionais: ['Forno'] };
  const manager = {
    findOne: async () => ({}), find: async () => [oferta],
    create: (_entity, item) => item,
    save: async (_entity, item) => item,
    transaction: async (fn) => fn(manager),
  };
  const perfil = { id: 2, servicos: [oferta] };
  const service = new ProfissionaisService({}, {}, {}, { findOne: async () => perfil },
    { manager }, {}, { findOne: async () => ({}) }, {});
  return { service, oferta };
}

test('oferta preserva campos omitidos por versões antigas do aplicativo', async () => {
  const { service, oferta } = fixture();
  await service.salvarMeusServicos({ id: 3 }, { servicos: [{ id: 1, nome: 'Limpeza' }] });
  assert.deepEqual(oferta.inclui, ['Pisos']);
  assert.deepEqual(oferta.naoInclui, ['Altura']);
  assert.deepEqual(oferta.opcionais, ['Forno']);
});

test('valida e atualiza cada lista do escopo', async () => {
  const { service, oferta } = fixture();
  await service.salvarMeusServicos({ id: 3 }, { servicos: [{ id: 1, nome: 'Limpeza',
    inclui: [' Superfícies '], naoInclui: [], opcionais: ['Janelas'] }] });
  assert.deepEqual(oferta.inclui, ['Superfícies']);
  assert.deepEqual(oferta.naoInclui, []);
  for (const invalid of [[''], ['a'.repeat(161)], Array(11).fill('item'), 'texto']) {
    await assert.rejects(service.salvarMeusServicos({ id: 3 },
      { servicos: [{ id: 1, nome: 'Limpeza', inclui: invalid }] }),
      (error) => error?.getResponse?.().code === 'ESCOPO_INVALIDO');
  }
});

test('snapshot não muda após alteração posterior da oferta', () => {
  const oferta = { inclui: ['Pisos'], naoInclui: null, opcionais: ['Janelas'] };
  const snapshot = snapshotEscopo(oferta);
  oferta.inclui.push('Banheiro');
  assert.deepEqual(snapshot, { inclui: ['Pisos'], naoInclui: [], opcionais: ['Janelas'] });
  assert.equal(snapshotEscopo(null), null);
});

test('migration retoma criação parcial e impede perda de escopo no rollback', async () => {
  const existing = new Set(['profissional_servicos.inclui']);
  const runner = {
    hasColumn: async (t, c) => existing.has(`${t}.${c}`),
    query: async (sql) => {
      const add = sql.match(/^ALTER TABLE (\w+) ADD COLUMN (\w+)/);
      if (add) existing.add(`${add[1]}.${add[2]}`);
      if (sql.startsWith('SELECT')) return [{ total: 1 }];
      return [];
    },
  };
  const migration = new EscopoOfertas1760138000000();
  await migration.up(runner);
  assert.equal(existing.size, 4);
  await assert.rejects(migration.down(runner), /preserve service scope/);
});
