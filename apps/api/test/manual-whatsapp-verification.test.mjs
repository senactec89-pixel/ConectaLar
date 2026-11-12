import assert from 'node:assert/strict';
import test from 'node:test';
import { AdminAuditoriaEntity } from '../dist/database/entities/admin-auditoria.entity.js';
import { ProfissionalPerfilEntity } from '../dist/database/entities/profissional-perfil.entity.js';
import { ProfissionalTelefoneVerificacaoEntity } from '../dist/database/entities/profissional-telefone-verificacao.entity.js';
import { UsuarioEntity } from '../dist/database/entities/usuario.entity.js';
import { HabilitacaoService } from '../dist/verificacao/habilitacao.service.js';
import { podeAtender } from '../dist/verificacao/habilitacao-profissional.js';

const professional = { id: 20, tipo: 'profissional' };
const administrator = { id: 99, tipo: 'administrador' };

function fixture({ mfaAtivo = true } = {}) {
  const profile = {
    id: 10,
    usuarioId: 20,
    ativo: true,
    verificado: true,
    habilitacaoEstado: 'pendente',
    usuario: { id: 20, ativo: true, tipo: 'profissional', telefoneNormalizado: '31999998888' },
  };
  let verification = null;
  const audits = [];
  const phoneRepo = {
    create: (value) => ({ ...value }),
    async save(value) {
      if (value.id === undefined) value.id = 501;
      verification = value;
      return value;
    },
    async findOne() { return verification; },
    createQueryBuilder() {
      const builder = {
        where() { return this; },
        andWhere() { return this; },
        async getCount() { return verification ? 1 : 0; },
      };
      return builder;
    },
  };
  const manager = {
    async findOne(entity, options) {
      const where = options?.where ?? {};
      if (entity === UsuarioEntity) {
        if (where.id === professional.id) return profile.usuario;
        if (where.id === administrator.id) return { ...administrator, ativo: true, mfaAtivo };
      }
      if (entity === ProfissionalPerfilEntity) {
        if (where.id === profile.id || where.usuarioId === profile.usuarioId) return profile;
      }
      if (entity === ProfissionalTelefoneVerificacaoEntity) return verification;
      return null;
    },
    getRepository(entity) {
      if (entity === ProfissionalTelefoneVerificacaoEntity) return phoneRepo;
      if (entity === AdminAuditoriaEntity) {
        return {
          create: (value) => value,
          async save(value) { audits.push(value); return value; },
        };
      }
      throw new Error(`Unexpected repository ${entity?.name}`);
    },
  };
  const phoneRepository = {
    manager: { async transaction(operation) { return operation(manager); } },
    async findOne() { return verification; },
    async save(value) { verification = value; return value; },
  };
  const profileRepository = {
    async findOne() { return profile; },
    manager: { async transaction(operation) { return operation(manager); } },
  };
  const userRepository = {
    async findOneBy({ id }) {
      if (id === administrator.id) return { ...administrator, ativo: true, mfaAtivo };
      if (id === professional.id) return profile.usuario;
      return null;
    },
  };
  return {
    profile,
    audits,
    get verification() { return verification; },
    service: new HabilitacaoService(
      profileRepository,
      userRepository,
      undefined,
      undefined,
      phoneRepository,
    ),
  };
}

function withManualConfig(operation) {
  const previous = {
    secret: process.env.AUTH_TOKEN_SECRET,
    enabled: process.env.WHATSAPP_MANUAL_ENABLED,
    number: process.env.WHATSAPP_MANUAL_NUMBER,
    provider: process.env.ID_ZAPSIGN_PHONE_ENABLED,
  };
  process.env.AUTH_TOKEN_SECRET = 'test-auth-secret-at-least-thirty-two-characters';
  process.env.WHATSAPP_MANUAL_ENABLED = 'true';
  process.env.WHATSAPP_MANUAL_NUMBER = '5531999990000';
  process.env.ID_ZAPSIGN_PHONE_ENABLED = 'false';
  return Promise.resolve().then(operation).finally(() => {
    if (previous.secret === undefined) delete process.env.AUTH_TOKEN_SECRET;
    else process.env.AUTH_TOKEN_SECRET = previous.secret;
    if (previous.enabled === undefined) delete process.env.WHATSAPP_MANUAL_ENABLED;
    else process.env.WHATSAPP_MANUAL_ENABLED = previous.enabled;
    if (previous.number === undefined) delete process.env.WHATSAPP_MANUAL_NUMBER;
    else process.env.WHATSAPP_MANUAL_NUMBER = previous.number;
    if (previous.provider === undefined) delete process.env.ID_ZAPSIGN_PHONE_ENABLED;
    else process.env.ID_ZAPSIGN_PHONE_ENABLED = previous.provider;
  });
}

const code = (expected) => (error) => error.getResponse?.().code === expected;

test('manual WhatsApp challenge stores only a keyed digest and returns a one-time wa.me link', async () => {
  await withManualConfig(async () => {
    const state = fixture();
    const { service } = state;
    const response = await service.iniciarTelefoneManual(professional, { consentimento: true });
    const phone = response.telefone;
    assert.match(phone.codigo, /^\d{8}$/);
    assert.equal(phone.codigoExibidoUmaVez, true);
    assert.equal(phone.linkWhatsApp, 'https://wa.me/5531999990000');
    assert.equal(phone.linkWhatsApp.includes(phone.codigo), false);
    assert.equal(state.verification.metodo, 'whatsapp_manual');
    assert.equal(state.verification.codigoHash.length, 64);
    assert.notEqual(state.verification.codigoHash, phone.codigo);
    assert.equal(Object.hasOwn(state.verification, 'codigo'), false);
    assert.equal(state.verification.tentativasRestantes, 5);
    assert.equal(podeAtender({ verificado: true, habilitacaoEstado: 'em_analise' }), false);
  });
});

test('manual WhatsApp confirmation requires MFA, matching sender and code, and is single-use', async () => {
  await withManualConfig(async () => {
    const state = fixture();
    const { service, audits } = state;
    const started = await service.iniciarTelefoneManual(professional, { consentimento: true });
    const body = { codigo: started.telefone.codigo, telefoneRemetente: '+55 (31) 99999-7777' };
    await assert.rejects(
      service.confirmarTelefoneManual(administrator, 10, body),
      code('DESAFIO_TELEFONE_NAO_CONFIRMADO'),
    );
    assert.equal(state.verification.estado, 'pendente');
    assert.equal(state.verification.tentativasRestantes, 4);
    assert.equal(audits.length, 0);

    const confirmed = await service.confirmarTelefoneManual(administrator, 10, {
      codigo: started.telefone.codigo,
      telefoneRemetente: '+55 (31) 99999-8888',
    });
    assert.equal(confirmed.telefone.estado, 'confirmada');
    assert.equal(state.verification.codigoHash, null);
    assert.equal(state.verification.tentativasRestantes, null);
    assert.equal(audits.length, 1);
    assert.equal(audits[0].acao, 'telefone_manual_confirmado');
    assert.equal(JSON.stringify(audits).includes(started.telefone.codigo), false);
    assert.equal(podeAtender({ verificado: true, habilitacaoEstado: 'pendente' }), false);
    await assert.rejects(
      service.confirmarTelefoneManual(administrator, 10, {
        codigo: started.telefone.codigo,
        telefoneRemetente: '31999998888',
      }),
      code('DESAFIO_TELEFONE_INDISPONIVEL'),
    );
  });
});

test('manual challenge is never re-exposed and expiry consumes its digest', async () => {
  await withManualConfig(async () => {
    const state = fixture();
    const { service } = state;
    const started = await service.iniciarTelefoneManual(professional, { consentimento: true });
    const repeated = await service.iniciarTelefoneManual(professional, { consentimento: true });
    assert.equal(repeated.telefone.codigo, undefined);
    assert.equal(repeated.telefone.codigoExibidoUmaVez, false);

    state.verification.expiraEm = new Date(Date.now() - 1_000);
    await assert.rejects(
      service.confirmarTelefoneManual(administrator, 10, {
        codigo: started.telefone.codigo,
        telefoneRemetente: '31999998888',
      }),
      code('DESAFIO_TELEFONE_EXPIRADO'),
    );
    assert.equal(state.verification.estado, 'expirada');
    assert.equal(state.verification.codigoHash, null);
  });
});

test('changing the account phone invalidates and erases a pending challenge', async () => {
  await withManualConfig(async () => {
    const state = fixture();
    const { service, profile } = state;
    await service.iniciarTelefoneManual(professional, { consentimento: true });
    profile.usuario.telefoneNormalizado = '31988887777';
    const result = await service.consultarTelefone(professional);
    assert.equal(result.telefone.estado, 'invalidada');
    assert.equal(state.verification.estado, 'invalidada');
    assert.equal(state.verification.codigoHash, null);
  });
});

test('manual WhatsApp challenge cannot be confirmed by admins without MFA or by the same user', async () => {
  await withManualConfig(async () => {
    const withoutMfa = fixture({ mfaAtivo: false });
    const started = await withoutMfa.service.iniciarTelefoneManual(professional, { consentimento: true });
    await assert.rejects(
      withoutMfa.service.confirmarTelefoneManual(administrator, 10, {
        codigo: started.telefone.codigo,
        telefoneRemetente: '31999998888',
      }),
      code('MFA_ADMIN_OBRIGATORIO'),
    );
    const { service } = fixture();
    await assert.rejects(
      service.confirmarTelefoneManual(professional, 10, {
        codigo: '12345678',
        telefoneRemetente: '31999998888',
      }),
      (error) => error.getStatus() === 403,
    );
  });
});

test('manual WhatsApp route remains disabled until official number and feature flag are configured', async () => {
  const previous = {
    enabled: process.env.WHATSAPP_MANUAL_ENABLED,
    number: process.env.WHATSAPP_MANUAL_NUMBER,
  };
  delete process.env.WHATSAPP_MANUAL_ENABLED;
  delete process.env.WHATSAPP_MANUAL_NUMBER;
  try {
    const { service } = fixture();
    await assert.rejects(
      service.iniciarTelefoneManual(professional, { consentimento: true }),
      code('VERIFICACAO_MANUAL_WHATSAPP_INDISPONIVEL'),
    );
  } finally {
    if (previous.enabled === undefined) delete process.env.WHATSAPP_MANUAL_ENABLED;
    else process.env.WHATSAPP_MANUAL_ENABLED = previous.enabled;
    if (previous.number === undefined) delete process.env.WHATSAPP_MANUAL_NUMBER;
    else process.env.WHATSAPP_MANUAL_NUMBER = previous.number;
  }
});

test('disabling the manual WhatsApp feature also blocks confirmation of an existing challenge', async () => {
  await withManualConfig(async () => {
    const state = fixture();
    const started = await state.service.iniciarTelefoneManual(professional, { consentimento: true });
    process.env.WHATSAPP_MANUAL_ENABLED = 'false';
    await assert.rejects(
      state.service.confirmarTelefoneManual(administrator, 10, {
        codigo: started.telefone.codigo,
        telefoneRemetente: '31999998888',
      }),
      code('VERIFICACAO_MANUAL_WHATSAPP_INDISPONIVEL'),
    );
    assert.equal(state.verification.estado, 'pendente');
  });
});
