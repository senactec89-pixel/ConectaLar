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
  const manager = {
    async findOne() { return p; },
    create(_type, data) { return data; },
    async save(type, data) { if (type !== ProfissionalPerfilEntity) audit.push(data); return data; },
  };
  const repo = { async findOne() { return p; },
    manager: { async transaction(fn) { return fn(manager); } },
    async findAndCount() { return [[p], 1]; },
  };
  const usuarios = { async findOneBy({ id }) { return id === 99
    ? { ...admin, ativo: true, mfaAtivo } : p.usuario; } };
  return { p, audit, service: new HabilitacaoService(repo, usuarios) };
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

test('paginacao administrativa valida limites', async () => {
  const { service } = habilitacaoFixture();
  for (const pagina of ['0', '-1', '100000', '1 OR 1', ['1']]) {
    await assert.rejects(service.listar(admin, { pagina }), codigo('HABILITACAO_DADOS_INVALIDOS'));
  }
  assert.equal((await service.listar(admin, {})).total, 1);
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
  const service = new VerificacaoService({}, {}, {}, {}, {}, {});
  for (const tipoDocumento of ['antecedentes_criminais', 'selfie', 'biometria']) {
    await assert.rejects(service.enviarMeuDocumento(profissional, { tipoDocumento,
      referenciaArquivo: 'arquivo.pdf' }), codigo('TIPO_DOCUMENTO_NAO_PERMITIDO'));
  }
});
