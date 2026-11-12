import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';
import { snapshotEscopo } from '../dist/domain/escopo-servico.js';
import { EscopoOfertas1760138000000 } from '../dist/database/migrations/1760138000000-EscopoOfertas.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';
const require = createRequire(import.meta.url);
const habilitacao = require('../dist/verificacao/habilitacao-profissional.js');

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

test('duracao aceita limites de P06 e recusa intervalo adicional', async () => {
  const { service, oferta } = fixture();
  for (const duracaoMinutos of [1, 1440]) {
    await service.salvarMeusServicos({ id: 3 }, {
      servicos: [{ id: 1, nome: 'Limpeza', duracaoMinutos, intervaloMinutos: 0 }],
    });
    assert.equal(oferta.duracaoMinutos, duracaoMinutos);
    assert.equal(oferta.intervaloMinutos, 0);
  }
  for (const duracaoMinutos of [0, 1441, 1.5]) {
    await assert.rejects(service.salvarMeusServicos({ id: 3 }, {
      servicos: [{ id: 1, nome: 'Limpeza', duracaoMinutos }],
    }), (error) => error?.getResponse?.().code === 'DURACAO_INVALIDA');
  }
  await assert.rejects(service.salvarMeusServicos({ id: 3 }, {
    servicos: [{ id: 1, nome: 'Limpeza', duracaoMinutos: 60, intervaloMinutos: 30 }],
  }), (error) => error?.getResponse?.().code === 'INTERVALO_INDISPONIVEL');
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

test('não cria pedido quando a oferta vista ou a oferta bloqueada mudou', async () => {
  const original = habilitacao.exigirHabilitacao;
  habilitacao.exigirHabilitacao = () => {};
  try {
    const oferta = { id: 1, profissionalId: 2, nome: 'Limpeza', categoriaId: null,
      ativo: true, precoInicial: null, duracaoMinutos: 60, intervaloMinutos: 0,
      inclui: ['Pisos'], naoInclui: [], opcionais: [] };
    let mudouNaTransacao = false;
    const manager = {
      transaction: async (fn) => fn(manager),
      findOne: async () => mudouNaTransacao ? { ...oferta, inclui: ['Outros'] } : oferta,
      save: async () => assert.fail('pedido não deve ser gravado'),
    };
    const profissional = { id: 2, usuarioId: 3, ativo: true,
      usuario: { ativo: true, tipo: 'profissional' } };
    const service = new SolicitacoesService({}, { findOne: async () => oferta }, {}, {}, {},
      { findOne: async () => profissional }, { manager, create: (value) => value },
      {}, {}, {}, { findOne: async () => ({ id: 4 }) }, {});
    service.validarDisponibilidade = async () => {};
    const body = { profissionalId: 2, servicoId: 1, descricao: 'Limpeza residencial completa',
      bairroAtendimento: 'Centro', dataServico: '2099-01-12', horarioServico: '14:00',
      escopoEsperado: { inclui: ['Antigo'], naoInclui: [], opcionais: [] } };
    const conflito = (e) => e?.getResponse?.().code === 'OFERTA_ALTERADA';
    await assert.rejects(service.criar({ id: 4, tipo: 'cliente' }, body), conflito);
    body.escopoEsperado.inclui = ['Pisos'];
    mudouNaTransacao = true;
    await assert.rejects(service.criar({ id: 4, tipo: 'cliente' }, body), conflito);
  } finally {
    habilitacao.exigirHabilitacao = original;
  }
});
