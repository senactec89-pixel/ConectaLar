import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { SolicitacaoOrcamentoEntity } from '../dist/database/entities/solicitacao-orcamento.entity.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { OrcamentoStatus } from '../dist/domain/orcamento-status.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';

const cliente = { id: 30, tipo: 'cliente' };
const profissional = { id: 20, tipo: 'profissional' };

function fixture() {
  const orcamentos = [];
  const eventos = [];
  const notificacoes = [];
  const solicitacao = {
    id: 1,
    clienteId: 30,
    cliente: { id: 30, nome: 'Cliente' },
    profissionalId: 10,
    profissional: {
      id: 10,
      usuarioId: 20,
      usuario: { id: 20, nome: 'Profissional', tipo: 'profissional' },
      verificado: true,
    },
    categoria: null,
    servicoId: null,
    nomeServico: null,
    enderecoId: null,
    endereco: null,
    enderecoSnapshot: null,
    descricao: 'Atendimento residencial agendado',
    bairroAtendimento: 'Centro',
    dataServico: '2099-01-10',
    horarioServico: '10:00',
    duracaoMinutos: 60,
    intervaloMinutos: 30,
    precoInicial: '80.00',
    precoFinal: null,
    status: 'aceita_agendada',
    cancelamentoMotivo: null,
    conclusaoContestacaoMotivo: null,
    naoComparecimentoMotivo: null,
    naoComparecimentoPorId: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  };
  const manager = {
    async findOne(type) {
      if (type === SolicitacaoOrcamentoEntity) {
        return [...orcamentos]
          .reverse()
          .find((item) => item.status === OrcamentoStatus.Pendente) ?? null;
      }
      return solicitacao;
    },
    create(_type, value) { return { ...value }; },
    async save(type, value) {
      if (type === SolicitacaoOrcamentoEntity && value.id === undefined) {
        value.id = orcamentos.length + 1;
        value.criadoEm = new Date();
        value.atualizadoEm = new Date();
        orcamentos.push(value);
      }
      if (type === SolicitacaoEventoEntity) {
        value.id = eventos.length + 1;
        value.criadoEm = new Date();
        value.ator = null;
        eventos.push(value);
      }
      return value;
    },
    async update(type, criteria, values) {
      assert.equal(type, SolicitacaoOrcamentoEntity);
      for (const orcamento of orcamentos) {
        if (
          orcamento.solicitacaoId === criteria.solicitacaoId &&
          orcamento.status === criteria.status
        ) {
          Object.assign(orcamento, values);
        }
      }
    },
  };
  const repo = {
    async findOne() { return solicitacao; },
    manager: {
      async transaction(_isolation, action) { return action(manager); },
      getRepository(type) {
        assert.equal(type, SolicitacaoEventoEntity);
        return { async find() { return [...eventos].reverse(); } };
      },
    },
  };
  const service = new SolicitacoesService(
    { async count() { return 0; } }, {}, {}, {}, {}, {}, repo,
    { async find() { return []; } },
    { async find() { return [...orcamentos].reverse(); } },
    {}, {},
    { async criar(input) { notificacoes.push(input); } },
  );
  return { service, solicitacao, orcamentos, eventos, notificacoes };
}

test('profissional propoe e somente aceite do cliente define preco final', async () => {
  const contexto = fixture();
  await assert.rejects(
    contexto.service.proporOrcamento(cliente, 1, {
      valor: 150,
      descricao: 'Servico completo com os materiais informados.',
    }),
    (error) => error.getStatus?.() === 403,
  );

  const proposta = await contexto.service.proporOrcamento(profissional, 1, {
    valor: '150,50',
    descricao: 'Servico completo com os materiais informados.',
  });
  assert.equal(proposta.solicitacao.precoFinal, null);
  assert.equal(proposta.solicitacao.orcamento.valor, 150.5);
  assert.equal(contexto.notificacoes[0].usuarioId, 30);

  await assert.rejects(
    contexto.service.responderOrcamento(profissional, 1, { aceitar: true }),
    (error) => error.getStatus?.() === 403,
  );
  const aceita = await contexto.service.responderOrcamento(cliente, 1, {
    aceitar: true,
  });
  assert.equal(aceita.solicitacao.precoFinal, 150.5);
  assert.equal(contexto.orcamentos[0].status, OrcamentoStatus.Aceito);
  assert.deepEqual(contexto.eventos.map((item) => item.tipo), [
    'orcamento_proposto',
    'orcamento_aceito',
  ]);
  assert.equal(contexto.notificacoes[1].usuarioId, 20);
});

test('revisao recusada preserva valor aceito e historico anterior', async () => {
  const contexto = fixture();
  await contexto.service.proporOrcamento(profissional, 1, {
    valor: 100,
    descricao: 'Primeira versao detalhada do servico solicitado.',
  });
  await contexto.service.responderOrcamento(cliente, 1, { aceitar: true });
  await contexto.service.proporOrcamento(profissional, 1, {
    valor: 125,
    descricao: 'Revisao por inclusao de material adicional solicitado.',
  });
  await contexto.service.responderOrcamento(cliente, 1, { aceitar: false });

  assert.equal(contexto.solicitacao.precoFinal, '100.00');
  assert.equal(contexto.orcamentos.length, 2);
  assert.deepEqual(contexto.orcamentos.map((item) => item.status), [
    OrcamentoStatus.Aceito,
    OrcamentoStatus.Recusado,
  ]);
});

test('revisao aceita substitui o acordo anterior e deixa um unico vigente', async () => {
  const contexto = fixture();
  await contexto.service.proporOrcamento(profissional, 1, {
    valor: 100,
    descricao: 'Primeira versao detalhada do servico solicitado.',
  });
  await contexto.service.responderOrcamento(cliente, 1, { aceitar: true });
  await contexto.service.proporOrcamento(profissional, 1, {
    valor: 125,
    descricao: 'Revisao por inclusao de material adicional solicitado.',
  });
  await contexto.service.responderOrcamento(cliente, 1, { aceitar: true });

  assert.equal(contexto.solicitacao.precoFinal, '125.00');
  assert.deepEqual(contexto.orcamentos.map((item) => item.status), [
    OrcamentoStatus.Substituido,
    OrcamentoStatus.Aceito,
  ]);
});

test('migration cria preco final e historico sem inferir aceite antigo', async () => {
  const migration = await readFile(
    new URL(
      '../src/database/migrations/1760129000000-OrcamentoFinal.ts',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(migration, /ADD preco_final DECIMAL\(10,2\) NULL/);
  assert.match(migration, /CREATE TABLE solicitacao_orcamentos/);
  assert.doesNotMatch(migration, /UPDATE solicitacoes[\s\S]*preco_final/);
});
