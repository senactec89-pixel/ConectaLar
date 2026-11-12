import assert from 'node:assert/strict';
import { test } from 'node:test';
import { PropostaAtendimentoCleanupService } from '../dist/solicitacoes/proposta-atendimento-cleanup.service.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';
import { SolicitacaoStatus } from '../dist/domain/solicitacao-status.js';

test('job expira propostas vencidas uma vez e registra evento sem alterar pedido', async () => {
  const agora = new Date('2026-11-10T12:00:00.000Z');
  let expirada = false;
  const eventos = [];
  const solicitacao = { id: 42, status: SolicitacaoStatus.AguardandoResposta };
  const manager = {
    findOne: async () => solicitacao,
    create: (_entity, value) => value,
    save: async (_entity, value) => {
      if (value.tipo === 'proposta_atendimento_expirada') eventos.push(value);
      return value;
    },
    query: async (sql) => {
      if (sql.includes('SELECT id, criado_em')) {
        return expirada ? [] : [{
          id: 81,
          criado_em: new Date('2026-11-07T10:00:00.000Z'),
          data_servico: '2026-11-13',
          horario_servico: '10:00',
          expira_em: null,
        }];
      }
      if (sql.includes("SET status='expirada'")) {
        expirada = true;
        return { affectedRows: 1 };
      }
      assert.fail(`Consulta inesperada: ${sql}`);
    },
  };
  const repository = {
    manager: {
      query: async (sql) => {
        if (sql.includes('FROM solicitacoes pedido')) return [];
        assert.match(sql, /SELECT DISTINCT solicitacao_id/);
        return expirada ? [] : [{ solicitacao_id: 42 }];
      },
      transaction: async (_isolation, operation) => operation(manager),
    },
  };
  const domain = new SolicitacoesService(
    {}, {}, {}, {}, {}, {}, repository, {}, {}, {}, {}, {},
  );
  const cleanup = new PropostaAtendimentoCleanupService(domain);

  assert.equal(await cleanup.processarVencidas(agora), 1);
  assert.equal(expirada, true);
  assert.equal(solicitacao.status, SolicitacaoStatus.AguardandoResposta);
  assert.equal(eventos.length, 1);
  assert.equal(eventos[0].tipo, 'proposta_atendimento_expirada');
  assert.equal(eventos[0].solicitacaoId, 42);
  assert.equal(eventos[0].atorId, null);
  assert.equal(await cleanup.processarVencidas(agora), 0);
});

test('job impede execucoes sobrepostas dentro da mesma instancia', async () => {
  let finalizar;
  let chamadas = 0;
  const domain = {
    expirarPedidosSemResposta: async () => 0,
    expirarNegociacoesInativas: async () => 0,
    expirarPropostasVencidas: () => {
      chamadas++;
      return new Promise((resolve) => { finalizar = resolve; });
    },
  };
  const cleanup = new PropostaAtendimentoCleanupService(domain);
  const primeira = cleanup.processarVencidas();

  assert.equal(await cleanup.processarVencidas(), 0);
  assert.equal(chamadas, 1);
  finalizar(3);
  assert.equal(await primeira, 3);
});
