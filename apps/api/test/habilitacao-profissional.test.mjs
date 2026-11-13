import assert from 'node:assert/strict';
import test from 'node:test';
import { habilitacaoProfissional, podeAtender, exigirHabilitacao, IdentidadeNaoConfigurada } from '../dist/verificacao/habilitacao-profissional.js';
import { HabilitacaoService } from '../dist/verificacao/habilitacao.service.js';
import { SolicitacoesService } from '../dist/solicitacoes/solicitacoes.service.js';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { VerificacaoService } from '../dist/verificacao/verificacao.service.js';

const profissional = { id: 20, tipo: 'profissional' };
const admin = { id: 99, tipo: 'administrador' };
const cliente = { id: 30, tipo: 'cliente' };
const codigo = (value) => (error) => error.getResponse?.().code === value;
function perfil() {
  return { id: 10, usuarioId: 20, ativo: true, verificado: true, habilitacaoEstado: 'pendente',
    usuario: { id: 20, tipo: 'profissional', nome: 'Teste', email: 'teste@example.invalid', ativo: true, emailVerificado: true } };
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

test('habilitacao manual de teste exige ambiente local, flag e estado aprovado', () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousFlag = process.env.HABILITACAO_MANUAL_LOCAL;
  try {
    process.env.NODE_ENV = 'development';
    process.env.HABILITACAO_MANUAL_LOCAL = 'true';
    const p = { ...perfil(), habilitacaoEstado: 'teste_local_aprovado' };
    assert.equal(habilitacaoProfissional(p).testeLocalElegivel, true);
    assert.equal(podeAtender(p), true);
    assert.equal(podeAtender({ ...p, ativo: false }), false);
    process.env.NODE_ENV = 'production';
    assert.equal(podeAtender(p), false);
  } finally {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousFlag === undefined) delete process.env.HABILITACAO_MANUAL_LOCAL;
    else process.env.HABILITACAO_MANUAL_LOCAL = previousFlag;
  }
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

function habilitacaoFixture(mfaAtivo = true) {
  const p = perfil();
  const audit = [];
  const filtrosAplicados = [];
  const manager = {
    async findOne(entity) { return entity.name === 'UsuarioEntity' ? p.usuario : p; },
    getRepository(entity) {
      if (entity.name === 'AdminAuditoriaEntity') {
        return {
          create: (data) => data,
          async save(data) { audit.push(data); return data; },
        };
      }
      return {};
    },
    async save(type, data) { if (type === ProfissionalPerfilEntity) return data; return data; },
  };
  const builder = {
    leftJoinAndSelect() { return this; },
    orderBy() { return this; },
    skip() { return this; },
    take() { return this; },
    andWhere(clause, parameters) { filtrosAplicados.push({ clause, parameters }); return this; },
    async getManyAndCount() { return [[p], 1]; },
  };
  const repo = { async findOne() { return p; },
    createQueryBuilder() { return builder; },
    manager: { async transaction(fn) { return fn(manager); } },
    async findAndCount() { return [[p], 1]; },
  };
  const usuarios = { async findOneBy({ id }) { return id === 99
    ? { ...admin, ativo: true, mfaAtivo } : p.usuario; } };
  return { p, audit, filtrosAplicados, service: new HabilitacaoService(repo, usuarios) };
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
  await service.analisar(admin, 10, { acao: 'reabrir', motivo: 'solicitacao_titular' });
  assert.equal(p.habilitacaoEstado, 'pendente');
  assert.equal(podeAtender(p), false);
  assert.equal(audit.length, 2);
});

test('admin pode liberar perfil local somente no modo local e a acao fica auditada', async () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousFlag = process.env.HABILITACAO_MANUAL_LOCAL;
  const { service, p, audit } = habilitacaoFixture();
  try {
    process.env.NODE_ENV = 'development';
    process.env.HABILITACAO_MANUAL_LOCAL = 'true';
    const result = await service.analisar(admin, 10, {
      acao: 'aprovar_teste_local', motivo: 'teste_fluxo_local',
    });
    assert.equal(p.habilitacaoEstado, 'teste_local_aprovado');
    assert.equal(result.habilitacao.podeAtender, true);
    assert.equal(audit.length, 1);
    assert.equal(JSON.parse(audit[0].detalhe).aprovacaoConcedida, true);
    assert.equal(JSON.parse(audit[0].detalhe).somenteTesteLocal, undefined);

    p.usuario.email = 'profissional.real@example.com';
    p.habilitacaoEstado = 'pendente';
    assert.equal((await service.analisar(admin, 10, {
      acao: 'aprovar_teste_local', motivo: 'teste_fluxo_local',
    })).habilitacao.podeAtender, true);
  } finally {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousFlag === undefined) delete process.env.HABILITACAO_MANUAL_LOCAL;
    else process.env.HABILITACAO_MANUAL_LOCAL = previousFlag;
  }
});

test('paginacao administrativa valida limites', async () => {
  const { service, filtrosAplicados } = habilitacaoFixture();
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
  await service.listar(admin, { pagina: '1', limite: '20', estado: 'teste_local_aprovado' });
  assert.ok(filtrosAplicados.some(({ parameters }) => parameters?.estado === 'teste_local_aprovado'));
});

test('dossie administrativo exige MFA, pagina documentos e nao expoe referencias privadas', async () => {
  const p = { ...perfil(), cidade: 'Belo Horizonte', uf: 'MG', servicos: [
    { id: 4, nome: 'Reparo', ativo: true, categoria: { nome: 'Manutencao' } },
  ] };
  const documentos = { async findAndCount(options) {
    assert.equal(options.where.profissionalId, 10);
    assert.equal(options.skip, 20);
    assert.equal(options.take, 20);
    return [[{
      id: 2, tipoDocumento: 'documento_identidade', status: 'pendente',
      referenciaArquivo: 'privado/segredo', observacao: 'nao expor',
      motivoRejeicao: null, criadoEm: new Date(), analisadoEm: null,
    }], 21];
  } };
  const perfis = { async findOne() { return p; } };
  const usuarios = { async findOneBy() { return { ...admin, ativo: true, mfaAtivo: true }; } };
  const service = new HabilitacaoService(perfis, usuarios, undefined, undefined, undefined, documentos);
  await assert.rejects(service.dossie(cliente, 10, {}), (error) => error.getStatus() === 403);
  await assert.rejects(service.dossie(admin, 0, {}), (error) => error.getStatus() === 400);
  await assert.rejects(service.dossie(admin, 10, { pagina: '0' }), (error) => error.getStatus() === 400);
  const result = await service.dossie(admin, 10, { pagina: '2' });
  assert.equal(result.profissional.habilitacao.podeAtender, false);
  assert.equal(result.profissional.ofertas[0].nome, 'Reparo');
  assert.equal(result.paginacao.total, 21);
  assert.equal(result.paginacao.temMais, false);
  assert.equal(result.documentos[0].status, 'pendente');
  assert.equal(JSON.stringify(result).includes('privado/segredo'), false);
  assert.equal(JSON.stringify(result).includes('nao expor'), false);
  const semMfa = new HabilitacaoService(perfis,
    { async findOneBy() { return { ...admin, ativo: true, mfaAtivo: false }; } },
    undefined, undefined, undefined, documentos);
  await assert.rejects(semMfa.dossie(admin, 10, {}), codigo('MFA_ADMIN_OBRIGATORIO'));
});

function solicitacoesFixture(status = 'aguardando_resposta') {
  const p = perfil();
  const now = new Date();
  const solicitacao = { id: 1, profissionalId: 10, clienteId: 30, profissional: p,
    cliente: { id: 30, nome: 'Cliente' }, status, categoria: null, enderecoId: 1,
    endereco: { id: 1, logradouro: 'Privado', numero: '123' }, criadoEm: now, atualizadoEm: now };
  const manager = { async findOne(type) { return type === ProfissionalPerfilEntity ? p : solicitacao; },
    async query() { return [{ negociacao: 0, mensagem_profissional: 0 }]; },
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
    { async findOne() { return p; } }, {}, { createQueryBuilder() { return builder; } }, {}, {},
    { async find() { return [{ dataInicio: '2026-10-12', dataFim: '2026-10-14' }]; } });
  const resposta = await service.minhaAgenda(profissional, { mes: '2026-10' });
  assert.equal(resposta.atendimentos[0].enderecoAtendimento, null);
  assert.equal(resposta.atendimentos[0].enderecoCompleto, null);
  assert.deepEqual(resposta.bloqueios, [
    { dataInicio: '2026-10-12', dataFim: '2026-10-14' },
  ]);
});

test('horarios publicos nao oferecem intervalos em uma data bloqueada', async () => {
  const service = new ProfissionaisService(
    {},
    {},
    {
      async find() {
        return [{ diaSemana: 0, horaInicio: '08:00', horaFim: '18:00', ativo: true }];
      },
    },
    {},
    { async findOne() { return { duracaoMinutos: 60, ativo: true }; } },
    { async find() { return []; } },
    {},
    {},
    { async findOne() { return { dataInicio: '2026-10-18', dataFim: '2026-10-18' }; } },
  );
  service.obter = async () => ({ profissional: { id: 10 } });

  const resposta = await service.horariosLivres(10, {
    data: '2026-10-18',
    servicoId: '5',
  });

  assert.equal(resposta.bloqueado, true);
  assert.deepEqual(resposta.intervalos, []);
});

test('upload nao pode ser usado para coletar antecedentes ou biometria sem politica', async () => {
  const service = new VerificacaoService({}, {}, {}, {}, {});
  for (const tipoDocumento of ['antecedentes_criminais', 'selfie', 'biometria']) {
    await assert.rejects(service.enviarMeuDocumento(profissional, { tipoDocumento,
      referenciaArquivo: 'arquivo.pdf' }), codigo('TIPO_DOCUMENTO_NAO_PERMITIDO'));
  }
});
