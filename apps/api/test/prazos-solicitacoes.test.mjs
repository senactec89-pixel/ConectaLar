import test from 'node:test';
import assert from 'node:assert/strict';
import { PrazosSolicitacoesService } from '../dist/solicitacoes/prazos-solicitacoes.service.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacaoPropostaEntity } from '../dist/database/entities/solicitacao-proposta.entity.js';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { NotificacaoEntity } from '../dist/database/entities/notificacao.entity.js';
import { PrazosEPropostasPreAceite1760136000000 } from '../dist/database/migrations/1760136000000-PrazosEPropostasPreAceite.js';
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
