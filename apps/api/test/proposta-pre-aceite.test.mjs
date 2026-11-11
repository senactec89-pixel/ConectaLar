import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { SolicitacaoPropostaEntity } from '../dist/database/entities/solicitacao-proposta.entity.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../dist/database/entities/profissional-disponibilidade.entity.js';

const require = createRequire(import.meta.url);
const habilitacao = require('../dist/verificacao/habilitacao-profissional.js');
const profissional = { id: 20, tipo: 'profissional' };
const cliente = { id: 30, tipo: 'cliente' };

function fixture() {
  const propostas = [];
  const eventos = [];
  const notificacoes = [];
  const perfil = { id: 10, usuarioId: 20, ativo: true, usuario: { id: 20, nome: 'Profissional' } };
  const pedido = {
    id: 1, clienteId: 30, cliente: { id: 30, nome: 'Cliente' }, profissionalId: 10,
    profissional: perfil, categoria: null, enderecoId: null, endereco: null,
    status: 'aguardando_resposta', descricao: 'Descricao original do atendimento.',
    dataServico: '2099-01-10', horarioServico: '10:00', duracaoMinutos: 60,
    intervaloMinutos: 0, prazoRespostaEm: new Date(Date.now() + 48 * 3_600_000),
    prazoInatividadeEm: null, criadoEm: new Date(), atualizadoEm: new Date(),
  };
  const manager = {
    async transaction(_isolation, action) { return action(this); },
    async findOne(entity, options) {
      if (entity === ProfissionalPerfilEntity) return perfil;
      if (entity === SolicitacaoEntity) return pedido;
      if (entity === SolicitacaoPropostaEntity) {
        return propostas.find((item) => item.id === options.where.id) ?? null;
      }
      throw new Error('Unexpected entity');
    },
    async find(entity) {
      if (entity === SolicitacaoPropostaEntity) return propostas.filter((item) => item.status === 'pendente');
      if (entity === ProfissionalDisponibilidadeEntity) return Array.from({ length: 7 }, (_, diaSemana) => ({ diaSemana, horaInicio: '00:00', horaFim: '23:59', ativo: true }));
      if (entity === SolicitacaoEntity) return [pedido];
      return [];
    },
    createQueryBuilder() {
      const query = { where() { return this; }, andWhere() { return this; }, async getOne() { return null; } };
      return query;
    },
    create(_entity, values) { return { ...values }; },
    async save(entity, value) {
      if (entity === SolicitacaoPropostaEntity && value.id === undefined) {
        Object.assign(value, { id: propostas.length + 1, criadoEm: new Date(), atualizadoEm: new Date() });
        propostas.push(value);
      }
      if (entity === SolicitacaoEventoEntity) {
        Object.assign(value, { id: eventos.length + 1, criadoEm: new Date(), ator: null });
        eventos.push(value);
      }
      return value;
    },
    getRepository(entity) {
      assert.equal(entity, SolicitacaoEventoEntity);
      return { async find() { return [...eventos].reverse(); } };
    },
  };
  const pedidoRepo = { manager, async findOne() { return pedido; } };
  const propostaRepo = { async find() { return [...propostas].reverse(); } };
  const service = new SolicitacoesService(
    { async count() { return 0; } }, {}, {}, {}, {}, {}, pedidoRepo,
    { async find() { return []; } }, { async find() { return []; } }, {}, {},
    { async criar(value) { notificacoes.push(value); } }, propostaRepo,
  );
  return { service, pedido, propostas, eventos, notificacoes };
}

test('proposta formal preserva pedido pendente e aceite do cliente agenda o escopo acordado', async () => {
  // A política atual bloqueia todos os profissionais em produção. A substituição
  // isola apenas o fluxo futuro; os testes de habilitação mantêm o bloqueio real.
  const original = habilitacao.exigirHabilitacao;
  habilitacao.exigirHabilitacao = () => {};
  try {
    const f = fixture();
    const proposta = await f.service.proporAntesAceite(profissional, 1, {
      dataServico: '2099-01-12', horarioServico: '14:00',
      escopo: 'Descricao completa do escopo proposto.',
    });
    assert.equal(proposta.solicitacao.status, 'aguardando_resposta');
    assert.equal(f.pedido.prazoRespostaEm, null);
    assert.ok(f.pedido.prazoInatividadeEm instanceof Date);
    assert.equal(f.eventos[0].motivo, 'Descricao original do atendimento.');
    const resposta = await f.service.responderPropostaAntesAceite(cliente, 1, 1, { aceitar: true });
    assert.equal(resposta.solicitacao.status, 'aceita_agendada');
    assert.equal(f.pedido.dataServico, '2099-01-12');
    assert.equal(f.pedido.descricao, 'Descricao completa do escopo proposto.');
    assert.equal(f.propostas[0].status, 'aceita');
    assert.deepEqual(f.notificacoes.map((item) => item.usuarioId), [30, 20]);
  } finally {
    habilitacao.exigirHabilitacao = original;
  }
});
