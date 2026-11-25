import assert from 'node:assert/strict';
import test from 'node:test';
import {
  habilitacaoPilotoAtiva,
  ofertaElegivelNoPiloto,
  politicaPilotoPublicavel,
} from '../dist/verificacao/habilitacao-piloto.js';
import { HabilitacaoService } from '../dist/verificacao/habilitacao.service.js';
import { ProfissionaisService } from '../dist/profissionais/profissionais.service.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { ProfissionalServicoEntity } from '../dist/database/entities/profissional-servico.entity.js';
import { UsuarioEntity } from '../dist/database/entities/usuario.entity.js';

const admin = (id) => ({ id, tipo: 'administrador' });
const validOffer = () => ({
  id: 4,
  profissionalId: 10,
  servicoCatalogoId: 5,
  categoriaId: 2,
  ativo: true,
  categoria: { ativo: true },
  servicoCatalogo: {
    ativo: true,
    categoriaId: 2,
    politicaPiloto: 'experiencia_declarada',
    criterioPiloto: 'Relato de experiencia pratica relacionado a tarefa.',
  },
  nivelExperienciaPiloto: 'experiencia_declarada',
  relatoExperienciaPiloto: 'Realizei esta tarefa em diferentes residencias e descrevo o escopo.',
  frequenciaExperienciaPiloto: 'recorrente',
  inicianteConfirmadoPiloto: false,
  revisaoExperienciaEstado: 'pendente',
  primeiroRevisorId: null,
  primeiraRevisaoEm: null,
  revisorFinalId: null,
  revisaoFinalEm: null,
  motivoRevisaoExperiencia: null,
});

function withEnvironment(values, run) {
  const previous = new Map(Object.keys(values).map((key) => [key, process.env[key]]));
  Object.assign(process.env, values);
  try {
    return run();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test('politica de piloto so liga explicitamente em ambiente isolado', () => {
  withEnvironment({ NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'false',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_dev' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), false);
  });
  withEnvironment({ NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_dev' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), true);
  });
  withEnvironment({ NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development', DB_HOST: 'db.example.com', DB_NAME: 'conectalar_dev' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), false);
  });
  withEnvironment({ NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_producao' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), false);
  });
  withEnvironment({ NODE_ENV: 'test', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_beta_test' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), true);
  });
  withEnvironment({ NODE_ENV: 'production', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'homologacao', DB_NAME: 'conectalar_producao' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), false);
  });
  withEnvironment({ NODE_ENV: 'production', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'production', DB_NAME: 'conectalar_homologacao' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), false);
  });
  withEnvironment({ NODE_ENV: 'production', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'homologacao', DB_NAME: 'conectalar_homologacao' }, () => {
    assert.equal(habilitacaoPilotoAtiva(), true);
  });
});

test('oferta do piloto falha fechada por padrao e requer tarefa e declaracao aprovadas', () => {
  const offer = validOffer();
  withEnvironment({ NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'false',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_dev' }, () => {
    assert.equal(ofertaElegivelNoPiloto({ ativo: true }), true);
  });
  withEnvironment({ NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_dev' }, () => {
    assert.equal(ofertaElegivelNoPiloto(offer), false);
    offer.revisaoExperienciaEstado = 'aprovada';
    assert.equal(ofertaElegivelNoPiloto(offer), true);
    assert.equal(ofertaElegivelNoPiloto({ ...offer, ativo: false }), false);
    assert.equal(ofertaElegivelNoPiloto({ ...offer, servicoCatalogo: { ...offer.servicoCatalogo, ativo: false } }), false);
    assert.equal(ofertaElegivelNoPiloto({ ...offer, categoria: { ativo: false } }), false);
    assert.equal(ofertaElegivelNoPiloto({ ...offer, categoriaId: 3 }), false);
    assert.equal(ofertaElegivelNoPiloto({ ...offer, revisaoExperienciaEstado: 'inconclusiva' }), false);
    assert.equal(ofertaElegivelNoPiloto({
      ...offer,
      servicoCatalogo: { ...offer.servicoCatalogo, criterioPiloto: 'curto' },
    }), false);
    assert.equal(ofertaElegivelNoPiloto({ ...offer, nivelExperienciaPiloto: 'iniciante' }), false);
    assert.equal(ofertaElegivelNoPiloto({
      ...offer,
      servicoCatalogo: { ...offer.servicoCatalogo, politicaPiloto: 'iniciante_ou_experiencia' },
      nivelExperienciaPiloto: 'iniciante',
      inicianteConfirmadoPiloto: true,
    }), true);
    assert.equal(ofertaElegivelNoPiloto({
      ...offer,
      servicoCatalogo: { ...offer.servicoCatalogo, politicaPiloto: 'iniciante_ou_experiencia' },
      nivelExperienciaPiloto: 'iniciante',
      inicianteConfirmadoPiloto: false,
    }), false);
  });
});

test('busca publica exige confirmacao registrada para oferta de iniciante', async () => {
  const conditions = [];
  const builder = {
    leftJoinAndSelect() { return this; },
    leftJoin() { return this; },
    where() { return this; },
    andWhere(condition) { conditions.push(condition); return this; },
    distinct() { return this; },
    orderBy() { return this; },
    addOrderBy() { return this; },
    skip() { return this; },
    take() { return this; },
    async getManyAndCount() { return [[], 0]; },
  };
  const service = new ProfissionaisService(
    {}, {}, {}, { createQueryBuilder: () => builder }, {}, {}, {}, {}, {},
  );
  const keys = ['NODE_ENV', 'CONECTALAR_HABILITACAO_PILOTO', 'CONECTALAR_STAGE', 'DB_HOST', 'DB_NAME'];
  const previous = new Map(keys.map((key) => [key, process.env[key]]));
  Object.assign(process.env, {
    NODE_ENV: 'development',
    CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development',
    DB_HOST: '127.0.0.1',
    DB_NAME: 'conectalar_dev',
  });
  try {
    await service.listar({});
    assert.ok(conditions.some((condition) =>
      typeof condition === 'string' && condition.includes('iniciante_confirmado_piloto = 1') &&
      condition.includes('scp.categoria_id = servicoFiltro.categoria_id')));
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('criterio publico precisa estar associado a politica explicita e texto minimo', () => {
  assert.equal(politicaPilotoPublicavel('fora_piloto', 'Criterio concreto e suficientemente longo.'), false);
  assert.equal(politicaPilotoPublicavel('experiencia_declarada', 'curto'), false);
  assert.equal(politicaPilotoPublicavel('experiencia_declarada', 'Criterio concreto e suficientemente longo.'), true);
});

test('aprovacao da tarefa exige dois administradores distintos e correcao reenviada', async () => {
  const oferta = validOffer();
  const perfil = { id: 10, usuarioId: 20, usuario: { id: 20, tipo: 'profissional' } };
  const auditoria = [];
  const manager = {
    async findOne(entity) {
      if (entity === ProfissionalPerfilEntity) return perfil;
      if (entity === ProfissionalServicoEntity) return oferta;
      assert.fail(`entidade inesperada: ${entity.name}`);
    },
    getRepository(entity) {
      assert.equal(entity.name, 'AdminAuditoriaEntity');
      return {
        create: (value) => value,
        async save(value) { auditoria.push(value); return value; },
      };
    },
    async save(entity, value) { return value; },
  };
  const perfis = { manager: { async transaction(run) { return run(manager); } } };
  const usuarios = { async findOneBy({ id }) {
    return { id, tipo: 'administrador', ativo: true, mfaAtivo: true };
  } };
  const service = new HabilitacaoService(perfis, usuarios);
  const keys = ['NODE_ENV', 'CONECTALAR_HABILITACAO_PILOTO', 'CONECTALAR_STAGE', 'DB_HOST', 'DB_NAME'];
  const previous = new Map(keys.map((key) => [key, process.env[key]]));
  process.env.NODE_ENV = 'development';
  process.env.CONECTALAR_HABILITACAO_PILOTO = 'true';
  process.env.CONECTALAR_STAGE = 'development';
  process.env.DB_HOST = '127.0.0.1';
  process.env.DB_NAME = 'conectalar_dev';
  const code = (expected) => (error) => error.getResponse?.().code === expected;
  try {
    const first = await service.analisarExperiencia(admin(90), 10, 4, {
      acao: 'aprovar', motivo: 'revisao_concluida',
    });
    assert.equal(first.revisaoExperiencia.estado, 'primeira_aprovacao');
    await assert.rejects(service.analisarExperiencia(admin(90), 10, 4, {
      acao: 'aprovar', motivo: 'revisao_concluida',
    }), code('REVISOR_INDEPENDENTE_OBRIGATORIO'));
    const final = await service.analisarExperiencia(admin(91), 10, 4, {
      acao: 'aprovar', motivo: 'revisao_concluida',
    });
    assert.equal(final.revisaoExperiencia.estado, 'aprovada');
    assert.equal(oferta.revisaoExperienciaEstado, 'aprovada');

    oferta.revisaoExperienciaEstado = 'primeira_aprovacao';
    oferta.primeiroRevisorId = null;
    oferta.primeiraRevisaoEm = null;
    await assert.rejects(service.analisarExperiencia(admin(91), 10, 4, {
      acao: 'aprovar', motivo: 'revisao_concluida',
    }), code('PRIMEIRA_REVISAO_INVALIDA'));

    oferta.revisaoExperienciaEstado = 'pendente';
    oferta.primeiroRevisorId = null;
    oferta.primeiraRevisaoEm = null;
    oferta.revisorFinalId = null;
    await service.analisarExperiencia(admin(90), 10, 4, {
      acao: 'solicitar_correcao', motivo: 'informacao_incompleta',
    });
    await assert.rejects(service.analisarExperiencia(admin(91), 10, 4, {
      acao: 'aprovar', motivo: 'revisao_concluida',
    }), code('CORRECAO_DA_DECLARACAO_OBRIGATORIA'));
    assert.equal(oferta.revisaoExperienciaEstado, 'precisa_correcao');
    assert.ok(auditoria.length >= 3);
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('revisao recusa declaracao de iniciante sem confirmacao registrada', async () => {
  const oferta = {
    ...validOffer(),
    nivelExperienciaPiloto: 'iniciante',
    relatoExperienciaPiloto: null,
    frequenciaExperienciaPiloto: null,
    inicianteConfirmadoPiloto: false,
    servicoCatalogo: {
      ...validOffer().servicoCatalogo,
      politicaPiloto: 'iniciante_ou_experiencia',
    },
  };
  const perfil = { id: 10, usuarioId: 20, usuario: { id: 20, tipo: 'profissional' } };
  const manager = {
    async findOne(entity) {
      if (entity === ProfissionalPerfilEntity) return perfil;
      if (entity === ProfissionalServicoEntity) return oferta;
      assert.fail(`entidade inesperada: ${entity.name}`);
    },
  };
  const perfis = { manager: { async transaction(run) { return run(manager); } } };
  const usuarios = { async findOneBy({ id }) {
    return { id, tipo: 'administrador', ativo: true, mfaAtivo: true };
  } };
  const service = new HabilitacaoService(perfis, usuarios);
  const keys = ['NODE_ENV', 'CONECTALAR_HABILITACAO_PILOTO', 'CONECTALAR_STAGE', 'DB_HOST', 'DB_NAME'];
  const previous = new Map(keys.map((key) => [key, process.env[key]]));
  Object.assign(process.env, {
    NODE_ENV: 'development', CONECTALAR_HABILITACAO_PILOTO: 'true',
    CONECTALAR_STAGE: 'development', DB_HOST: '127.0.0.1', DB_NAME: 'conectalar_dev',
  });
  try {
    await assert.rejects(service.analisarExperiencia(admin(90), 10, 4, {
      acao: 'aprovar', motivo: 'revisao_concluida',
    }), (error) => error.getResponse?.().code === 'DECLARACAO_EXPERIENCIA_INCOMPLETA');
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});
