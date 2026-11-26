import assert from 'node:assert/strict';
import test from 'node:test';
import { habilitacaoProfissional, podeAtender, exigirHabilitacao, IdentidadeNaoConfigurada } from '../dist/verificacao/habilitacao-profissional.js';
import { HabilitacaoService } from '../dist/verificacao/habilitacao.service.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { ProfissionalHabilitacaoRevisaoEntity } from '../dist/database/entities/profissional-habilitacao-revisao.entity.js';
import { UsuarioEntity } from '../dist/database/entities/usuario.entity.js';
import { VerificacaoService } from '../dist/verificacao/verificacao.service.js';

const profissional = { id: 20, tipo: 'profissional' };
const admin = { id: 99, tipo: 'administrador' };
const cliente = { id: 30, tipo: 'cliente' };
const codigo = (value) => (error) => error.getResponse?.().code === value;
function perfil() {
  return { id: 10, usuarioId: 20, ativo: true, verificado: true, habilitacaoEstado: 'pendente',
    usuario: { id: 20, tipo: 'profissional', nome: 'Teste', ativo: true, emailVerificado: true } };
}

test('sem fornecedores nao ha aprovacao, nem por selo legado, estado adulterado ou flag', () => {
  for (const estado of [undefined, 'pendente', 'em_analise', 'suspenso', 'aprovado']) {
    const p = { ...perfil(), habilitacaoEstado: estado };
    assert.equal(podeAtender(p), false);
    assert.throws(() => exigirHabilitacao(p), codigo('PROFISSIONAL_HABILITACAO_PENDENTE'));
    const status = habilitacaoProfissional(p);
    assert.equal(status.documentoAnalisado, true);
    assert.equal(status.etapas.find((e) => e.codigo === 'antecedentes').status, 'aguardando_politica');
    assert.notEqual(status.estado, 'aprovado');
  }
  assert.equal(podeAtender(null), false);
  assert.equal(habilitacaoProfissional(perfil(), 'confirmado', 'confirmado').podeAtender, false);
});

test('beta local libera somente perfil listado em banco de teste local', () => {
  const nomes = ['NODE_ENV', 'CONECTALAR_BETA_LOCAL', 'DB_HOST', 'DB_NAME',
    'CONECTALAR_BETA_LOCAL_PROFISSIONAL_IDS'];
  const anteriores = Object.fromEntries(nomes.map((nome) => [nome, process.env[nome]]));
  Object.assign(process.env, { NODE_ENV: 'test', CONECTALAR_BETA_LOCAL: 'true',
    DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_beta_test',
    CONECTALAR_BETA_LOCAL_PROFISSIONAL_IDS: '10' });
  try {
    assert.equal(podeAtender(perfil()), true);
    assert.doesNotThrow(() => exigirHabilitacao(perfil()));
    assert.equal(podeAtender({ ...perfil(), habilitacaoEstado: 'suspenso' }), false);
    assert.equal(podeAtender({ ...perfil(), ativo: false }), false);
    assert.equal(podeAtender({ ...perfil(), id: 11 }), false);
    process.env.DB_NAME = 'conectalar_dev';
    assert.equal(podeAtender(perfil()), false);
    process.env.DB_NAME = 'conectalar_beta_test';
    process.env.NODE_ENV = 'production';
    assert.equal(podeAtender(perfil()), false);
  } finally {
    for (const nome of nomes) {
      if (anteriores[nome] === undefined) delete process.env[nome];
      else process.env[nome] = anteriores[nome];
    }
  }
});

test('provider desabilitado nao simula identidade ou prova de vida', async () => {
  const provider = new IdentidadeNaoConfigurada();
  assert.equal(provider.disponivel, false);
  await assert.rejects(provider.iniciar(20), codigo('VERIFICACAO_IDENTIDADE_INDISPONIVEL'));
  await assert.rejects(provider.consultar('forjada'), codigo('VERIFICACAO_IDENTIDADE_INDISPONIVEL'));
});

function habilitacaoFixture(mfaAtivo = true, mfaSegundoAtivo = true) {
  const p = perfil();
  const audit = [];
  const revisoes = [];
  let proximoId = 1;
  const revisaoRepo = {
    async findOne({ where }) {
      return revisoes.find((item) => item.profissionalId === where.profissionalId &&
        item.estado === where.estado && (where.id === undefined || item.id === where.id)) ?? null;
    },
    create(data) { return { ...data }; },
    async save(value) {
      if (value.id === undefined) value.id = proximoId++;
      const index = revisoes.findIndex((item) => item.id === value.id);
      if (index < 0) revisoes.push(value);
      else revisoes[index] = value;
      return value;
    },
  };
  const manager = {
    async findOne(entity, options) {
      if (entity === UsuarioEntity) {
        const id = options?.where?.id;
        if (id === p.usuarioId) return p.usuario;
        return id === 99 || id === 100
          ? { id, tipo: 'administrador', ativo: true, mfaAtivo: id === 99 ? mfaAtivo : mfaSegundoAtivo }
          : null;
      }
      return p;
    },
    getRepository(entity) {
      if (entity.name === 'AdminAuditoriaEntity') {
        return {
          create: (data) => data,
          async save(data) { audit.push(data); return data; },
        };
      }
      if (entity === ProfissionalHabilitacaoRevisaoEntity) return revisaoRepo;
      if (entity.name === 'ProfissionalDocumentoVerificacaoEntity') return { async find() { return []; } };
      if (entity.name === 'ProfissionalIdentidadeVerificacaoEntity' ||
        entity.name === 'ProfissionalTelefoneVerificacaoEntity') return { async findOne() { return null; } };
      return {};
    },
    async save(type, data) { if (type === ProfissionalPerfilEntity) return data; return data; },
  };
  const builder = {
    leftJoinAndSelect() { return this; },
    orderBy() { return this; },
    skip() { return this; },
    take() { return this; },
    andWhere() { return this; },
    async getManyAndCount() { return [[p], 1]; },
  };
  const repo = { async findOne() { return p; },
    createQueryBuilder() { return builder; },
    manager: { async transaction(fn) { return fn(manager); } },
    async findAndCount() { return [[p], 1]; },
  };
  const usuarios = { async findOneBy({ id }) { return id === 99 || id === 100
    ? { id, tipo: 'administrador', ativo: true, mfaAtivo: id === 99 ? mfaAtivo : mfaSegundoAtivo } : p.usuario; } };
  return { p, audit, revisoes, service: new HabilitacaoService(repo, usuarios,
    undefined, undefined, undefined, revisaoRepo) };
}

test('identidade recusa resultado declarado pelo app, CPF e selfie sem integracao', async () => {
  const { service } = habilitacaoFixture();
  for (const body of [{ aprovado: true }, { cpf: '123' }, { selfie: 'base64' }]) {
    await assert.rejects(service.iniciarIdentidade(profissional, body), codigo('HABILITACAO_DADOS_INVALIDOS'));
  }
  await assert.rejects(service.iniciarIdentidade(profissional, {}), codigo('VERIFICACAO_IDENTIDADE_INDISPONIVEL'));
  await assert.rejects(service.iniciarIdentidade(cliente, {}), (e) => e.getStatus() === 403);
});

test('revisao e idempotente, auditada e nao remove suspensao', async () => {
  const { service, p, audit } = habilitacaoFixture();
  p.habilitacaoEstado = 'suspenso';
  await service.solicitarRevisao(profissional, {});
  await service.solicitarRevisao(profissional, {});
  assert.equal(audit.length, 1);
  assert.equal(audit[0].atorId, 20);
  assert.equal(JSON.parse(audit[0].detalhe).efeito, 'nao_altera_estado_de_aprovacao_ou_suspensao');
  assert.equal(p.habilitacaoEstado, 'suspenso');
  assert.ok(p.habilitacaoRevisaoEm instanceof Date);
  assert.equal((await service.minha(profissional)).habilitacao.podeAtender, false);
});

test('habilitacao administrativa exige papel e MFA, inclusive na leitura', async () => {
  const { service } = habilitacaoFixture(false);
  await assert.rejects(service.listar(admin, {}), codigo('MFA_ADMIN_OBRIGATORIO'));
  await assert.rejects(service.analisar(admin, 10, { acao: 'suspender', motivo: 'revisao_cadastral' }), codigo('MFA_ADMIN_OBRIGATORIO'));
  await assert.rejects(service.listar(profissional, {}), (e) => e.getStatus() === 403);
});

test('admin nao aprova sem dependencias nem aceita detalhes criminais arbitrarios', async () => {
  const { service, p, audit } = habilitacaoFixture();
  await assert.rejects(service.analisar(admin, 10, { acao: 'aprovar' }), codigo('HABILITACAO_DEPENDENCIAS_PENDENTES'));
  await assert.rejects(service.analisar(admin, 10, { acao: 'suspender', motivo: 'Texto com dados pessoais' }), codigo('HABILITACAO_DADOS_INVALIDOS'));
  await assert.rejects(service.analisar(admin, 10, { acao: 'suspender', motivo: 'suspeita_fraude', antecedentes: 'dados' }), codigo('HABILITACAO_DADOS_INVALIDOS'));
  assert.equal(p.habilitacaoEstado, 'pendente');
  assert.equal(audit.length, 0);
  await assert.rejects(service.analisar(admin, 10, { acao: ['reabrir'], motivo: 'solicitacao_titular' }), codigo('HABILITACAO_DADOS_INVALIDOS'));
  await assert.rejects(service.analisar(admin, 10, { acao: 'suspender', motivo: ['suspeita_fraude'] }), codigo('HABILITACAO_DADOS_INVALIDOS'));
  await service.analisar(admin, 10, { acao: 'suspender', motivo: 'suspeita_fraude' });
  assert.equal(p.habilitacaoEstado, 'suspenso');
  await assert.rejects(service.analisar(admin, 10, { acao: 'iniciar_analise', motivo: 'revisao_cadastral' }), codigo('HABILITACAO_SUSPENSA'));
  const primeira = await service.analisar(admin, 10, { acao: 'reabrir', motivo: 'solicitacao_titular' });
  assert.equal(primeira.decisaoDupla.estado, 'aguardando_segundo_revisor');
  assert.equal(p.habilitacaoEstado, 'suspenso');
  await service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'reabrir', motivo: 'solicitacao_titular', revisaoId: primeira.decisaoDupla.revisaoId,
  });
  assert.equal(p.habilitacaoEstado, 'pendente');
  assert.equal(podeAtender(p), false);
  assert.equal(audit.length, 4);
});

test('dupla revisao oculta o primeiro voto e aplica somente resultado identico de outro admin', async () => {
  const { service, p } = habilitacaoFixture();
  const primeira = await service.analisar(admin, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral',
  });
  assert.equal(primeira.decisaoDupla.estado, 'aguardando_segundo_revisor');
  assert.equal(p.habilitacaoEstado, 'pendente');

  const filaPrimeiro = await service.listar(admin, {});
  const filaSegundo = await service.listar({ id: 100, tipo: 'administrador' }, {});
  const revisaoPrimeiro = filaPrimeiro.profissionais[0].revisaoAdministrativa;
  const revisaoSegundo = filaSegundo.profissionais[0].revisaoAdministrativa;
  assert.deepEqual(revisaoPrimeiro, {
    id: primeira.decisaoDupla.revisaoId,
    estado: 'aguardando_segundo_revisor',
    jaVotou: true,
  });
  assert.deepEqual(revisaoSegundo, {
    id: primeira.decisaoDupla.revisaoId,
    estado: 'aguardando_segundo_revisor',
    jaVotou: false,
  });
  assert.equal('acaoPrimeiroVoto' in revisaoSegundo, false);

  const retry = await service.analisar(admin, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral', revisaoId: primeira.decisaoDupla.revisaoId,
  });
  assert.equal(retry.decisaoDupla.estado, 'aguardando_segundo_revisor');
  await assert.rejects(service.analisar(admin, 10, {
    acao: 'reabrir', motivo: 'solicitacao_titular', revisaoId: primeira.decisaoDupla.revisaoId,
  }), codigo('HABILITACAO_REVISOR_REPETIDO'));

  const segunda = await service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral', revisaoId: primeira.decisaoDupla.revisaoId,
  });
  assert.equal(segunda.decisaoDupla.estado, 'concluida');
  assert.equal(p.habilitacaoEstado, 'em_analise');
  assert.equal(podeAtender(p), false);
});

test('segundo administrador também precisa estar ativo com MFA', async () => {
  const { service, p } = habilitacaoFixture(true, false);
  const primeira = await service.analisar(admin, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral',
  });
  await assert.rejects(service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral', revisaoId: primeira.decisaoDupla.revisaoId,
  }), codigo('MFA_ADMIN_OBRIGATORIO'));
  assert.equal(p.habilitacaoEstado, 'pendente');
});

test('suspensão imediata cancela revisão aberta e invalida o identificador anterior', async () => {
  const { service, p } = habilitacaoFixture();
  const primeira = await service.analisar(admin, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral',
  });
  const suspensao = await service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'suspender', motivo: 'suspeita_fraude',
  });
  assert.equal(suspensao.decisaoDupla.estado, 'suspensao_imediata');
  assert.equal(p.habilitacaoEstado, 'suspenso');
  await assert.rejects(service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'reabrir', motivo: 'solicitacao_titular', revisaoId: primeira.decisaoDupla.revisaoId,
  }), codigo('HABILITACAO_REVISAO_INDISPONIVEL'));
});

test('votos divergentes preservam o estado e encerram a revisão sem liberar atendimento', async () => {
  const { service, p } = habilitacaoFixture();
  const primeira = await service.analisar(admin, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral',
  });
  const segunda = await service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'reabrir', motivo: 'solicitacao_titular', revisaoId: primeira.decisaoDupla.revisaoId,
  });
  assert.equal(segunda.decisaoDupla.estado, 'divergente');
  assert.equal(p.habilitacaoEstado, 'pendente');
  assert.equal(podeAtender(p), false);
});

test('alteracao do dossie cancela a revisao para impedir decisao sobre evidencias desatualizadas', async () => {
  const { service, p } = habilitacaoFixture();
  const primeira = await service.analisar(admin, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral',
  });
  p.atualizadoEm = new Date();
  const segunda = await service.analisar({ id: 100, tipo: 'administrador' }, 10, {
    acao: 'iniciar_analise', motivo: 'revisao_cadastral', revisaoId: primeira.decisaoDupla.revisaoId,
  });
  assert.equal(segunda.decisaoDupla.estado, 'cancelada');
  assert.equal(p.habilitacaoEstado, 'pendente');
  assert.equal(podeAtender(p), false);
});

test('paginacao administrativa valida limites', async () => {
  const { service } = habilitacaoFixture();
  for (const pagina of ['0', '-1', '100000', '1 OR 1', ['1']]) {
    await assert.rejects(service.listar(admin, { pagina }), codigo('HABILITACAO_DADOS_INVALIDOS'));
  }
  const result = await service.listar(admin, { pagina: '1', limite: '20', termo: 'Teste', estado: 'pendente' });
  assert.equal(result.pagina, 1);
  assert.equal(result.total, 1);
  assert.deepEqual(result.paginacao, {
    pagina: 1,
    limite: 20,
    total: 1,
    totalPaginas: 1,
    temMais: false,
  });
  assert.equal(result.profissionais[0].nome, 'Teste');
});

function solicitacoesFixture(status = 'aguardando_resposta') {
  const p = perfil();
  const now = new Date();
  const solicitacao = { id: 1, profissionalId: 10, clienteId: 30, profissional: p,
    cliente: { id: 30, nome: 'Cliente' }, status, categoria: null, enderecoId: 1,
    endereco: { id: 1, logradouro: 'Privado', numero: '123' }, criadoEm: now, atualizadoEm: now };
  const manager = { async findOne(type) { return type === ProfissionalPerfilEntity ? p : solicitacao; },
    async save() { assert.fail('Nao pode gravar aceite sem habilitacao'); } };
  const repo = { async findOne() { return solicitacao; },
    manager: {
      async transaction(_isolation, fn) { return fn(manager); },
      getRepository() { return { async find() { return []; } }; },
    } };
  const service = new SolicitacoesService({ async count() { return 0; } }, {}, {}, {}, {},
    { async findOne() { return p; } }, repo,
    { async find() { return []; }, async findOne() { return null; } },
    { async find() { return []; } }, {},
    { async findOne() { return cliente; } },
    { async criar() { assert.fail('Nao deve notificar aceite bloqueado'); } });
  return { service, p, solicitacao };
}

test('solicitacao direta na API e barrada mesmo com documento aprovado', async () => {
  const { service } = solicitacoesFixture();
  await assert.rejects(service.criar(cliente, { profissionalId: 10, descricao: 'Preciso de manutencao',
    bairroAtendimento: 'Centro', dataServico: '2026-12-01', horarioServico: '10:00' }), codigo('PROFISSIONAL_HABILITACAO_PENDENTE'));
});

test('aceite e barrado dentro da transacao do perfil', async () => {
  const { service } = solicitacoesFixture();
  await assert.rejects(service.aceitar(profissional, 1), codigo('PROFISSIONAL_HABILITACAO_PENDENTE'));
});

test('pedidos antigos nao liberam endereco ao profissional pendente; titular mantem acesso', async () => {
  for (const status of ['aceita_agendada', 'conclusao_confirmada']) {
    const { service } = solicitacoesFixture(status);
    const privado = (await service.obter(profissional, 1)).solicitacao;
    assert.equal(privado.enderecoCompletoLiberado, false);
    assert.equal(privado.enderecoAtendimento, null);
    const titular = (await service.obter(cliente, 1)).solicitacao;
    assert.equal(titular.enderecoAtendimento.logradouro, 'Privado');
  }
});

test('agenda nao contorna protecao de endereco de pedidos antigos', async () => {
  const { p, solicitacao } = solicitacoesFixture('aceita_agendada');
  const builder = new Proxy({}, { get: (_, key) => key === 'getMany' ? async () => [solicitacao] : () => builder });
  const service = new ProfissionaisService({}, {}, { async find() { return []; } },
    { async findOne() { return p; } }, {}, { createQueryBuilder() { return builder; } }, {}, {});
  const resposta = await service.minhaAgenda(profissional, { mes: '2026-10' });
  assert.equal(resposta.atendimentos[0].enderecoAtendimento, null);
  assert.equal(resposta.atendimentos[0].enderecoCompleto, null);
});

test('upload nao pode ser usado para coletar antecedentes ou biometria sem politica', async () => {
  const service = new VerificacaoService({}, {}, {}, {}, {});
  for (const tipoDocumento of ['antecedentes_criminais', 'selfie', 'biometria']) {
    await assert.rejects(service.enviarMeuDocumento(profissional, { tipoDocumento,
      referenciaArquivo: 'arquivo.pdf' }), codigo('TIPO_DOCUMENTO_NAO_PERMITIDO'));
  }
});
