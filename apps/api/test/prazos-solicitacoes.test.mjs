import test from 'node:test';
import assert from 'node:assert/strict';
import { PrazosSolicitacoesService } from '../dist/solicitacoes/prazos-solicitacoes.service.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacaoPropostaEntity } from '../dist/database/entities/solicitacao-proposta.entity.js';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { SolicitacaoOrcamentoEntity } from '../dist/database/entities/solicitacao-orcamento.entity.js';
import { SolicitacaoReagendamentoEntity } from '../dist/database/entities/solicitacao-reagendamento.entity.js';
import { NotificacaoEntity } from '../dist/database/entities/notificacao.entity.js';
import { PrazosEPropostasPreAceite1760136000000 } from '../dist/database/migrations/1760136000000-PrazosEPropostasPreAceite.js';
import { PrazosPropostasAgendadas1760137000000 } from '../dist/database/migrations/1760137000000-PrazosPropostasAgendadas.js';
import { horarioIniciado } from '../dist/domain/agendamento.js';

function fixture(pedido, propostas = []) {
  const eventos = [];
  const notificacoes = [];
  const perfil = { id: pedido.profissionalId, usuarioId: 20 };
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
    async find(entity, options) {
      assert.equal(entity, SolicitacaoPropostaEntity);
      return propostas.filter((item) =>
        item.solicitacaoId === options.where.solicitacaoId && item.status === 'pendente');
    },
    create(_entity, values) { return { ...values }; },
    async save(entity, value) {
      if (entity === SolicitacaoEventoEntity) eventos.push(value);
      if (entity === NotificacaoEntity) notificacoes.push(value);
      return value;
    },
  };
  const pedidosRepo = {
    manager,
    async find() {
      const prazo = pedido.prazoInatividadeEm ?? pedido.prazoRespostaEm;
      const horarioChegou = pedido.prazoRespostaEm != null && pedido.dataServico &&
        horarioIniciado(pedido.dataServico, pedido.horarioServico);
      return pedido.status === 'aguardando_resposta' && ((prazo && prazo <= new Date()) || horarioChegou)
        ? [pedido] : [];
    },
    async findOne() { return pedido; },
  };
  const propostasRepo = {
    async find() {
      return propostas.filter((item) => item.status === 'pendente' && item.venceEm <= new Date());
    },
  };
  return { service: new PrazosSolicitacoesService(pedidosRepo, propostasRepo), eventos, notificacoes };
}

test('pedido sem resposta é cancelado uma vez e avisa os dois participantes', async () => {
  const pedido = {
    id: 1, clienteId: 30, profissionalId: 10, status: 'aguardando_resposta',
    prazoRespostaEm: new Date(Date.now() - 1), prazoInatividadeEm: null,
    dataServico: '2099-01-01', horarioServico: '10:00',
  };
  const { service, eventos, notificacoes } = fixture(pedido);
  await service.processar();
  await service.processar();
  assert.equal(pedido.status, 'cancelada');
  assert.equal(eventos.length, 1);
  assert.equal(eventos[0].tipo, 'pedido_expirado_sem_resposta');
  assert.equal(eventos[0].atorId, null);
  assert.deepEqual(notificacoes.map((item) => item.usuarioId), [30, 20]);
});

test('pedido sem resposta termina no horário solicitado se as 48 horas ainda não passaram', async () => {
  const pedido = {
    id: 1, clienteId: 30, profissionalId: 10, status: 'aguardando_resposta',
    prazoRespostaEm: new Date(Date.now() + 86_400_000), prazoInatividadeEm: null,
    dataServico: '2000-01-01', horarioServico: '10:00',
  };
  const { service, eventos, notificacoes } = fixture(pedido);
  await service.processar();
  assert.equal(pedido.status, 'cancelada');
  assert.equal(eventos[0].tipo, 'pedido_expirado_horario');
  assert.equal(notificacoes.length, 2);
});

test('vencimento da proposta mantém pedido aberto até o prazo de inatividade', async () => {
  const prazo = new Date(Date.now() + 100_000);
  const pedido = {
    id: 1, clienteId: 30, profissionalId: 10, status: 'aguardando_resposta',
    prazoRespostaEm: null, prazoInatividadeEm: prazo,
  };
  const proposta = { id: 2, solicitacaoId: 1, status: 'pendente', venceEm: new Date(Date.now() - 1) };
  const { service, eventos, notificacoes } = fixture(pedido, [proposta]);
  await service.processar();
  assert.equal(proposta.status, 'expirada');
  assert.equal(pedido.status, 'aguardando_resposta');
  assert.equal(pedido.prazoInatividadeEm, prazo);
  assert.equal(eventos[0].tipo, 'proposta_pre_aceite_expirada');
  assert.equal(notificacoes.length, 2);

  pedido.prazoInatividadeEm = new Date(Date.now() - 1);
  await service.processar();
  assert.equal(pedido.status, 'cancelada');
  assert.equal(eventos[1].tipo, 'pedido_expirado_inatividade');
  assert.equal(notificacoes.length, 4);
});

test('vencimento de orçamento e reagendamento preserva atendimento e combinado', async () => {
  const pedido = { id: 1, clienteId: 30, profissionalId: 10, status: 'aceita_agendada',
    dataServico: '2099-01-01', horarioServico: '10:00', precoFinal: '90.00' };
  const orcamento = { id: 2, solicitacaoId: 1, status: 'pendente', venceEm: new Date(Date.now() - 1) };
  const reagendamento = { id: 3, solicitacaoId: 1, status: 'pendente', venceEm: new Date(Date.now() - 1) };
  const eventos = [];
  const notificacoes = [];
  const manager = {
    async transaction(_isolation, action) { return action(this); },
    async findOne(entity) {
      if (entity === SolicitacaoEntity) return pedido;
      if (entity === SolicitacaoOrcamentoEntity) return orcamento;
      if (entity === SolicitacaoReagendamentoEntity) return reagendamento;
      if (entity === ProfissionalPerfilEntity) return { usuarioId: 20 };
      throw new Error('Unexpected entity');
    },
    create(_entity, values) { return { ...values }; },
    async save(entity, value) {
      if (entity === SolicitacaoEventoEntity) eventos.push(value);
      if (entity === NotificacaoEntity) notificacoes.push(value);
      return value;
    },
  };
  const repo = (item) => ({ async find() { return item.status === 'pendente' ? [item] : []; } });
  const service = new PrazosSolicitacoesService(
    { manager, async find() { return []; } }, { async find() { return []; } },
    repo(orcamento), repo(reagendamento),
  );
  await service.processar();
  await service.processar();
  assert.equal(orcamento.status, 'expirado');
  assert.equal(reagendamento.status, 'expirado');
  assert.equal(pedido.status, 'aceita_agendada');
  assert.equal(pedido.precoFinal, '90.00');
  assert.equal(pedido.dataServico, '2099-01-01');
  assert.deepEqual(eventos.map((item) => item.tipo), ['orcamento_expirado', 'reagendamento_expirado']);
  assert.equal(notificacoes.length, 4);
});

test('migração retoma alteração parcial e bloqueia rollback com propostas', async () => {
  const colunas = new Set(['prazo_resposta_em']);
  const indices = new Set();
  let tabelaPropostas = false;
  const executadas = [];
  const runner = {
    async hasColumn(_table, column) { return colunas.has(column); },
    async hasTable() { return tabelaPropostas; },
    async getTable() { return { indices: [...indices].map((name) => ({ name })) }; },
    async query(sql) {
      executadas.push(sql);
      if (sql.includes('ADD COLUMN prazo_inatividade_em')) colunas.add('prazo_inatividade_em');
      if (sql.includes('ADD INDEX idx_solicitacoes_prazo_resposta')) indices.add('idx_solicitacoes_prazo_resposta');
      if (sql.includes('ADD INDEX idx_solicitacoes_prazo_inatividade')) indices.add('idx_solicitacoes_prazo_inatividade');
      if (sql.includes('CREATE TABLE solicitacao_propostas')) tabelaPropostas = true;
      if (sql.startsWith('SELECT COUNT(*) AS total FROM solicitacao_propostas')) return [{ total: 1 }];
      return [];
    },
  };
  const migration = new PrazosEPropostasPreAceite1760136000000();
  await migration.up(runner);
  const totalAposPrimeiraExecucao = executadas.length;
  await migration.up(runner);
  assert.equal(executadas.length, totalAposPrimeiraExecucao);
  assert.equal(colunas.size, 2);
  assert.equal(indices.size, 2);
  assert.equal(tabelaPropostas, true);
  await assert.rejects(migration.down(runner), /preserve request proposals/);
  assert.equal(tabelaPropostas, true);
});

test('migração de propostas agendadas retoma após falha no CHECK e protege dados', async () => {
  const colunas = new Set();
  const indices = new Set();
  const checks = new Set(['chk_orcamentos_status', 'chk_reagendamentos_status']);
  let falharUmaVez = true;
  const runner = {
    async hasColumn(table, column) { return colunas.has(`${table}.${column}`); },
    async getTable(table) {
      return { indices: [...indices].filter((item) => item.startsWith(`${table}.`))
        .map((item) => ({ name: item.slice(table.length + 1) })) };
    },
    async query(sql, params) {
      if (sql.includes('information_schema.TABLE_CONSTRAINTS')) {
        return checks.has(params[1]) ? [{ CONSTRAINT_NAME: params[1] }] : [];
      }
      const table = /ALTER TABLE (\w+)/.exec(sql)?.[1];
      if (sql.includes('ADD COLUMN vence_em')) colunas.add(`${table}.vence_em`);
      const addIndex = /ADD INDEX (\w+)/.exec(sql)?.[1];
      if (addIndex) indices.add(`${table}.${addIndex}`);
      const drop = /DROP CONSTRAINT (\w+)/.exec(sql)?.[1];
      if (drop) checks.delete(drop);
      const add = /ADD CONSTRAINT (\w+)/.exec(sql)?.[1];
      if (add === 'chk_reagendamentos_status' && falharUmaVez) {
        falharUmaVez = false;
        throw new Error('falha simulada');
      }
      if (add) checks.add(add);
      if (sql.startsWith('SELECT COUNT(*) AS total')) return [{ total: 1 }];
      return [];
    },
  };
  const migration = new PrazosPropostasAgendadas1760137000000();
  await assert.rejects(migration.up(runner), /falha simulada/);
  await migration.up(runner);
  assert.equal(colunas.size, 2);
  assert.equal(indices.size, 2);
  assert.equal(checks.size, 2);
  await assert.rejects(migration.down(runner), /preserve proposal deadlines/);
});
