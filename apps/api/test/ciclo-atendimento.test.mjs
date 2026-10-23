import assert from 'node:assert/strict';
import test from 'node:test';
import { SolicitacaoEventoEntity } from '../dist/database/entities/solicitacao-evento.entity.js';
import { SolicitacaoEntity } from '../dist/database/entities/solicitacao.entity.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { databaseRuntimeOptions } from '../dist/database/database.config.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';

const cliente = { id: 30, tipo: 'cliente' };
const profissional = { id: 20, tipo: 'profissional' };

test('historico de atendimento integra os metadados do banco em producao', () => {
  const anterior = {
    DB_HOST: process.env.DB_HOST,
    DB_USER: process.env.DB_USER,
    DB_PASSWORD: process.env.DB_PASSWORD,
    DB_NAME: process.env.DB_NAME,
  };
  Object.assign(process.env, {
    DB_HOST: '127.0.0.1',
    DB_USER: 'teste',
    DB_PASSWORD: 'teste',
    DB_NAME: 'teste',
  });
  try {
    assert.ok(databaseRuntimeOptions().entities.includes(SolicitacaoEventoEntity));
  } finally {
    for (const [key, value] of Object.entries(anterior)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

function fixture(status = 'aceita_agendada', dataServico = '2020-01-01') {
  const eventos = [];
  const notificacoes = [];
  const perfil = {
    id: 10,
    usuarioId: 20,
    ativo: true,
    verificado: true,
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
    dataServico,
    horarioServico: '10:00',
    duracaoMinutos: 60,
    intervaloMinutos: 30,
    precoInicial: null,
    status,
    cancelamentoMotivo: null,
    conclusaoContestacaoMotivo: null,
    naoComparecimentoMotivo: null,
    naoComparecimentoPorId: null,
    criadoEm: new Date('2020-01-01T12:00:00Z'),
    atualizadoEm: new Date('2020-01-01T12:00:00Z'),
  };
  const manager = {
    async findOne(type) {
      return type === ProfissionalPerfilEntity ? perfil : solicitacao;
    },
    create(_type, value) {
      return {
        id: eventos.length + 1,
        criadoEm: new Date(),
        ator: value.atorId === null
          ? null
          : { id: value.atorId, nome: 'Participante', tipo: value.atorId === 30 ? 'cliente' : 'profissional' },
        ...value,
      };
    },
    async save(type, value) {
      if (type === SolicitacaoEventoEntity) eventos.push(value);
      return value;
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
    { async find() { return []; } }, {}, {},
    { async criar(input) { notificacoes.push(input); } },
  );
  return { service, solicitacao, eventos, notificacoes };
}

test('conclusao exige declaracao profissional e confirmacao do cliente', async () => {
  const { service, solicitacao, eventos, notificacoes } = fixture();
  await assert.rejects(service.concluir(cliente, 1), (error) => error.getStatus() === 403);

  const pendente = await service.concluir(profissional, 1);
  assert.equal(pendente.solicitacao.status, 'conclusao_pendente');
  assert.equal(eventos[0].tipo, 'servico_marcado_realizado');

  const concluida = await service.confirmarConclusao(cliente, 1);
  assert.equal(concluida.solicitacao.status, 'conclusao_confirmada');
  assert.deepEqual(eventos.map((item) => item.tipo), [
    'servico_marcado_realizado',
    'conclusao_confirmada',
  ]);
  assert.equal(concluida.solicitacao.eventos.length, 2);
  assert.equal(notificacoes.length, 2);
  assert.equal(solicitacao.status, 'conclusao_confirmada');
});

test('cliente pode contestar conclusao com motivo auditado', async () => {
  const { service, eventos } = fixture('conclusao_pendente');
  const resposta = await service.contestarConclusao(cliente, 1, {
    motivo: 'O servico combinado ainda nao foi finalizado.',
  });
  assert.equal(resposta.solicitacao.status, 'conclusao_contestada');
  assert.equal(resposta.solicitacao.conclusaoContestacaoMotivo, 'O servico combinado ainda nao foi finalizado.');
  assert.equal(eventos[0].motivo, 'O servico combinado ainda nao foi finalizado.');
});

test('nao comparecimento so pode ser informado depois do inicio e pela parte envolvida', async () => {
  const futuro = fixture('aceita_agendada', '2099-01-01');
  await assert.rejects(
    futuro.service.informarNaoComparecimento(cliente, 1, {
      motivo: 'A outra parte nao chegou no horario combinado.',
    }),
    (error) => error.getResponse?.().code === 'ATENDIMENTO_NAO_INICIADO',
  );

  const atual = fixture();
  const informado = await atual.service.informarNaoComparecimento(cliente, 1, {
    motivo: 'O profissional nao chegou no horario combinado.',
  });
  assert.equal(informado.solicitacao.status, 'nao_comparecimento_informado');
  assert.equal(informado.solicitacao.naoComparecimentoPorId, 30);

  await assert.rejects(
    atual.service.contestarNaoComparecimento(cliente, 1, {
      motivo: 'Quero alterar o relato que eu mesmo registrei.',
    }),
    (error) => error.getStatus() === 403,
  );
  const contestado = await atual.service.contestarNaoComparecimento(profissional, 1, {
    motivo: 'Eu compareci e possuo registros do atendimento.',
  });
  assert.equal(contestado.solicitacao.status, 'conclusao_contestada');
  assert.equal(atual.eventos.at(-1).tipo, 'nao_comparecimento_contestado');
});

test('cancelamento aceito exige motivo, ocorre antes do inicio e notifica a outra parte', async () => {
  const agendada = fixture('aceita_agendada', '2099-01-01');
  const resposta = await agendada.service.cancelar(profissional, 1, {
    motivo: 'Imprevisto profissional sem possibilidade de reagendar.',
  });
  assert.equal(resposta.solicitacao.status, 'cancelada');
  assert.equal(agendada.eventos[0].atorId, 20);
  assert.equal(agendada.notificacoes[0].usuarioId, 30);

  const iniciada = fixture();
  await assert.rejects(
    iniciada.service.cancelar(cliente, 1, {
      motivo: 'Tentativa de cancelar depois do inicio.',
    }),
    (error) => error.getResponse?.().code === 'CANCELAMENTO_APOS_INICIO',
  );
});
