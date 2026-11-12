import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { ExpiraNegociacaoInativa1760144000000 } from '../dist/database/migrations/1760144000000-ExpiraNegociacaoInativa.js';
import { SolicitacaoStatus } from '../dist/domain/solicitacao-status.js';
import {
  calcularExpiracaoNegociacao,
  expirarNegociacaoInativa,
  prazoNegociacaoInativaMs,
} from '../dist/solicitacoes/negociacao-prazo.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';

test('prazo da negociacao e de 96 horas e vence no instante limite', () => {
  const inicio = new Date('2026-11-10T12:00:00.000Z');
  const limite = calcularExpiracaoNegociacao(inicio);

  assert.equal(prazoNegociacaoInativaMs, 96 * 60 * 60 * 1000);
  assert.equal(limite.toISOString(), '2026-11-14T12:00:00.000Z');
});

test('job encerra negociacao vencida uma vez e registra evento', async () => {
  const agora = new Date('2026-11-14T12:00:00.000Z');
  const pedido = {
    id: 17,
    status: SolicitacaoStatus.AguardandoResposta,
    prazoInatividadeEm: new Date('2026-11-14T12:00:00.000Z'),
  };
  const eventos = [];
  const manager = {
    findOne: async () => pedido,
    query: async () => [{ pendente: 0 }],
    create: (_entity, value) => value,
    save: async (entity, value) => {
      if (entity === SolicitacaoEntity) Object.assign(pedido, value);
      if (entity === SolicitacaoEventoEntity) eventos.push(value);
      return value;
    },
  };
  const repository = {
    manager: {
      query: async () => pedido.status === SolicitacaoStatus.AguardandoResposta
        ? [{ id: pedido.id }]
        : [],
      transaction: async (_isolation, operation) => operation(manager),
    },
  };
  const service = new SolicitacoesService({}, {}, {}, {}, {}, {}, repository, {}, {}, {}, {}, {});

  assert.equal(await service.expirarNegociacoesInativas(agora), 1);
  assert.equal(pedido.status, SolicitacaoStatus.NegociacaoExpirada);
  assert.equal(eventos.length, 1);
  assert.equal(eventos[0].tipo, 'negociacao_expirada');
  assert.equal(eventos[0].motivo, 'inatividade_96h');
  assert.equal(await service.expirarNegociacoesInativas(agora), 0);
});

test('proposta pendente impede expirar a negociacao ate sua propria resposta', async () => {
  const pedido = {
    id: 17,
    status: SolicitacaoStatus.AguardandoResposta,
    prazoInatividadeEm: new Date('2026-11-14T12:00:00.000Z'),
  };
  const manager = {
    query: async () => [{ pendente: 1 }],
    save: async () => assert.fail('negociacao com proposta pendente nao expira'),
    create: (_entity, value) => value,
  };

  assert.equal(await expirarNegociacaoInativa(manager, pedido, new Date('2026-11-14T12:00:00.000Z')), false);
  assert.equal(pedido.status, SolicitacaoStatus.AguardandoResposta);
});

test('migration define o novo estado e bloqueia rollback com historico existente', async () => {
  const statements = [];
  const migration = new ExpiraNegociacaoInativa1760144000000();
  await migration.up({
    query: async (sql) => {
      statements.push(sql);
      if (sql.includes('SELECT VERSION()')) return [{ version: '8.0.0' }];
      if (sql.includes('SELECT CURRENT_TIMESTAMP')) return [{ agora: new Date('2026-11-10T12:00:00.000Z') }];
      return [];
    },
  });
  assert.ok(statements.some((sql) => sql.includes('prazo_inatividade_em')));
  assert.ok(statements.some((sql) => sql.includes("'negociacao_expirada'")));

  await assert.rejects(
    migration.down({ query: async (sql) => sql.includes('COUNT(*) AS total') ? [{ total: 1 }] : [] }),
    /Rollback blocked/,
  );
});
