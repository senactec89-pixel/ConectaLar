import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { ProfissionalBloqueioEntity } from '../dist/database/entities/profissional-bloqueio.entity.js';
import { ProfissionalDisponibilidadeEntity } from '../dist/database/entities/profissional-disponibilidade.entity.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import {
  ReagendamentoStatus,
  SolicitacaoReagendamentoEntity,
} from '../dist/database/entities/solicitacao-reagendamento.entity.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';

const cliente = { id: 30, tipo: 'cliente' };
const profissional = { id: 20, tipo: 'profissional' };

function fixture() {
  const propostas = [];
  const eventos = [];
  const notificacoes = [];
  const perfil = {
    id: 10,
    usuarioId: 20,
    ativo: true,
    usuario: { id: 20, nome: 'Profissional', tipo: 'profissional', ativo: true },
  };
  const solicitacao = {
    id: 1,
    clienteId: 30,
    cliente: { id: 30, nome: 'Cliente' },
    profissionalId: 10,
    profissional: perfil,
    categoria: null,
    categoriaId: null,
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
    precoInicial: null,
    status: 'aceita_agendada',
    cancelamentoMotivo: null,
    conclusaoContestacaoMotivo: null,
    naoComparecimentoMotivo: null,
    naoComparecimentoPorId: null,
    criadoEm: new Date(),
    atualizadoEm: new Date(),
  };
  const disponibilidades = Array.from({ length: 7 }, (_, diaSemana) => ({
    diaSemana,
    horaInicio: '00:00',
    horaFim: '23:59',
    ativo: true,
  }));
  const manager = {
    async findOne(type) {
      if (type === ProfissionalPerfilEntity) return perfil;
      if (type === SolicitacaoReagendamentoEntity) {
        return [...propostas]
          .reverse()
          .find((item) => item.status === ReagendamentoStatus.Pendente) ?? null;
      }
      return solicitacao;
    },
    async find(type) {
      if (type === ProfissionalDisponibilidadeEntity) return disponibilidades;
      if (type === SolicitacaoEntity) return [solicitacao];
      return [];
    },
    createQueryBuilder(type) {
      assert.equal(type, ProfissionalBloqueioEntity);
      const builder = new Proxy(
        {},
        {
          get: (_, key) => key === 'getOne' ? async () => null : () => builder,
        },
      );
      return builder;
    },
    create(_type, value) {
      return { ...value };
    },
    async save(type, value) {
      if (type === SolicitacaoReagendamentoEntity) {
        if (value.id === undefined) {
          value.id = propostas.length + 1;
          value.criadoEm = new Date();
          value.atualizadoEm = new Date();
          propostas.push(value);
        }
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
      assert.equal(type, SolicitacaoReagendamentoEntity);
      for (const proposta of propostas) {
        if (
          proposta.solicitacaoId === criteria.solicitacaoId &&
          proposta.status === criteria.status
        ) {
          Object.assign(proposta, values);
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
  const reagendamentos = {
    async find() { return [...propostas].reverse(); },
  };
  const service = new SolicitacoesService(
    { async count() { return 0; } }, {}, {}, {}, {}, {}, repo,
    reagendamentos, { async find() { return []; } }, {}, {},
    { async criar(input) { notificacoes.push(input); } },
  );
  return { service, solicitacao, propostas, eventos, notificacoes };
}

test('cliente contrapropoe e somente o profissional pode confirmar', async () => {
  const contexto = fixture();
  const proposta = await contexto.service.proporReagendamento(cliente, 1, {
    dataServico: '2099-01-12',
    horarioServico: '14:00',
    motivo: 'Preciso ajustar o atendimento para o periodo da tarde.',
  });
  assert.equal(proposta.solicitacao.reagendamento.propostoPorId, 30);
  assert.equal(contexto.notificacoes[0].usuarioId, 20);

  await assert.rejects(
    contexto.service.responderReagendamento(cliente, 1, { aceitar: true }),
    (error) => error.getResponse?.().code === 'REAGENDAMENTO_RESPOSTA_PROPRIA',
  );
  const resposta = await contexto.service.responderReagendamento(
    profissional,
    1,
    { aceitar: true },
  );
  assert.equal(resposta.solicitacao.dataServico, '2099-01-12');
  assert.equal(resposta.solicitacao.horarioServico, '14:00');
  assert.equal(contexto.propostas[0].status, ReagendamentoStatus.Aceito);
  assert.deepEqual(contexto.eventos.map((item) => item.tipo), [
    'reagendamento_proposto',
    'reagendamento_aceito',
  ]);
  assert.equal(contexto.notificacoes[1].usuarioId, 30);
});

test('contraproposta substitui a proposta pendente sem apagar o historico', async () => {
  const contexto = fixture();
  await contexto.service.proporReagendamento(profissional, 1, {
    dataServico: '2099-01-11',
    horarioServico: '09:00',
    motivo: 'Tive um imprevisto e preciso alterar o primeiro horario.',
  });
  await contexto.service.proporReagendamento(cliente, 1, {
    dataServico: '2099-01-13',
    horarioServico: '15:00',
    motivo: 'Esse horario funciona melhor para acompanhar o atendimento.',
  });
  assert.equal(contexto.propostas.length, 2);
  assert.equal(contexto.propostas[0].status, ReagendamentoStatus.Cancelado);
  assert.equal(contexto.propostas[1].status, ReagendamentoStatus.Pendente);
  assert.equal(contexto.propostas[1].propostoPorId, 30);

  await contexto.service.responderReagendamento(profissional, 1, {
    aceitar: false,
  });
  assert.equal(contexto.propostas[1].status, ReagendamentoStatus.Recusado);
  assert.equal(contexto.propostas.length, 2);
});

test('migration identifica o autor legado sem perder o historico', async () => {
  const migration = await readFile(
    new URL(
      '../src/database/migrations/1760128000000-ContrapropostaReagendamento.ts',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(migration, /SET reagendamento\.proposto_por_id = profissional\.usuario_id/);
  assert.match(migration, /REFERENCES usuarios\(id\) ON DELETE SET NULL/);
});
