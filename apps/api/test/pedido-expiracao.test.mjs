import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SolicitacaoStatus } from '../dist/domain/solicitacao-status.js';
import { ExpiraPedidosSemResposta1760143000000 } from '../dist/database/migrations/1760143000000-ExpiraPedidosSemResposta.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';
import { calcularExpiracaoPedido, pedidoSemRespostaExpirou } from '../dist/solicitacoes/pedido-prazo.js';

test('pedido inicial vence exatamente 48 horas depois da criacao', () => {
  const criadoEm = new Date('2026-11-10T12:00:00.000Z');
  const expiraEm = calcularExpiracaoPedido(criadoEm);

  assert.equal(expiraEm.toISOString(), '2026-11-12T12:00:00.000Z');
  assert.equal(pedidoSemRespostaExpirou(expiraEm, new Date('2026-11-12T11:59:59.999Z')), false);
  assert.equal(pedidoSemRespostaExpirou(expiraEm, expiraEm), true);
});

test('migration preserva conversas historicas e protege o rollback do novo estado', async () => {
  const statements = [];
  const migration = new ExpiraPedidosSemResposta1760143000000();
  await migration.up({
    query: async (sql) => {
      statements.push(sql);
      if (sql.includes('SELECT VERSION()')) return [{ version: '8.0.0' }];
      return [];
    },
  });

  const backfill = statements.find((sql) => sql.includes('UPDATE solicitacoes pedido'));
  assert.match(backfill, /evento\.tipo='negociacao_iniciada'/);
  assert.match(backfill, /mensagens_atendimento/);
  assert.match(backfill, /mensagem\.autor_id/);
  assert.match(statements.find((sql) => sql.includes('ADD CONSTRAINT chk_solicitacoes_status')), /'expirada'/);

  await assert.rejects(
    migration.down({ query: async (sql) => sql.includes('COUNT(*) AS total') ? [{ total: 1 }] : [] }),
    /Rollback blocked/,
  );
});

test('job expira pedido sem resposta atomicamente e grava evento', async () => {
  const agora = new Date('2026-11-12T12:00:00.000Z');
  let pedido;
  const eventos = [];
  const manager = {
    findOne: async () => pedido,
    query: async (sql) => {
      assert.match(sql, /EXISTS\(SELECT 1 FROM solicitacao_eventos/);
      return [{ negociacao: 0, mensagem_profissional: 0 }];
    },
    create: (_entity, value) => value,
    save: async (_entity, value) => {
      if ('status' in value) pedido = value;
      else eventos.push(value);
      return value;
    },
  };
  const repository = {
    manager: {
      query: async (sql) => {
        assert.match(sql, /FROM solicitacoes pedido/);
        return pedido?.status === SolicitacaoStatus.AguardandoResposta ? [{ id: pedido.id }] : [];
      },
      transaction: async (_isolation, operation) => operation(manager),
    },
  };
  pedido = {
    id: 42,
    profissionalId: 8,
    status: SolicitacaoStatus.AguardandoResposta,
    criadoEm: new Date('2026-11-10T12:00:00.000Z'),
    expiraEm: calcularExpiracaoPedido(new Date('2026-11-10T12:00:00.000Z')),
  };
  const service = new SolicitacoesService({}, {}, {}, {}, {}, {}, repository, {}, {}, {}, {}, {});

  assert.equal(await service.expirarPedidosSemResposta(agora), 1);
  assert.equal(pedido.status, SolicitacaoStatus.Expirada);
  assert.equal(pedido.expiraEm.toISOString(), '2026-11-12T12:00:00.000Z');
  assert.equal(eventos.length, 1);
  assert.equal(eventos[0].tipo, 'solicitacao_expirada');
  assert.equal(eventos[0].statusAnterior, SolicitacaoStatus.AguardandoResposta);
  assert.equal(eventos[0].statusNovo, SolicitacaoStatus.Expirada);
  assert.equal(await service.expirarPedidosSemResposta(agora), 0);
});

test('job preserva pedido cuja negociacao ou resposta por mensagem ja comecou', async () => {
  const pedido = {
    id: 42,
    profissionalId: 8,
    status: SolicitacaoStatus.AguardandoResposta,
    criadoEm: new Date('2026-11-10T12:00:00.000Z'),
    expiraEm: new Date('2026-11-11T12:00:00.000Z'),
  };
  const manager = {
    findOne: async () => pedido,
    query: async () => [{ negociacao: 1, mensagem_profissional: 0 }],
    create: (_entity, value) => value,
    save: async () => assert.fail('pedido respondido nao deve ser salvo como expirado'),
  };
  const repository = {
    manager: {
      query: async () => [{ id: pedido.id }],
      transaction: async (_isolation, operation) => operation(manager),
    },
  };
  const service = new SolicitacoesService({}, {}, {}, {}, {}, {}, repository, {}, {}, {}, {}, {});

  assert.equal(await service.expirarPedidosSemResposta(new Date('2026-11-12T12:00:00.000Z')), 0);
  assert.equal(pedido.status, SolicitacaoStatus.AguardandoResposta);
});

test('resposta profissional apos o limite expira o pedido e e recusada mesmo antes do job', async () => {
  const pedido = {
    id: 52,
    profissionalId: 8,
    clienteId: 10,
    profissional: { id: 8, usuarioId: 80 },
    status: SolicitacaoStatus.AguardandoResposta,
    criadoEm: new Date(Date.now() - 49 * 60 * 60 * 1000),
    expiraEm: new Date(Date.now() - 60 * 60 * 1000),
  };
  const eventos = [];
  const perfil = { id: 8, usuarioId: 80, ativo: true };
  const manager = {
    findOne: async (entity) => entity.name === 'ProfissionalPerfilEntity' ? perfil : pedido,
    query: async () => [{ negociacao: 0, mensagem_profissional: 0 }],
    create: (_entity, value) => value,
    save: async (entity, value) => {
      if (entity.name === 'SolicitacaoEventoEntity') eventos.push(value);
      return value;
    },
  };
  const repository = {
    findOne: async () => pedido,
    manager: { transaction: async (_isolation, operation) => operation(manager) },
  };
  const service = new SolicitacoesService({}, {}, {}, {}, {}, {}, repository, {}, {}, {}, {}, {});

  await assert.rejects(
    service.recusar({ id: 80, tipo: 'profissional' }, pedido.id),
    (error) => error?.getStatus?.() === 409 && error?.response?.code === 'SOLICITACAO_EXPIRADA',
  );
  assert.equal(pedido.status, SolicitacaoStatus.Expirada);
  assert.equal(eventos.length, 1);
  assert.equal(eventos[0].tipo, 'solicitacao_expirada');
});
