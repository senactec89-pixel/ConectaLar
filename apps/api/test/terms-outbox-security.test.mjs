import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AuthService } from '../dist/auth/auth.service.js';
import { AuthGuard } from '../dist/auth/auth.guard.js';
import {
  criptografarCodigoOutbox,
  descriptografarCodigoOutbox,
} from '../dist/auth/email-outbox.service.js';

function contextFor(request) {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  };
}

function guard({
  accepted,
  path = '/clientes/me',
  tipo = 'cliente',
  mfaAtivo = false,
  method = 'GET',
}) {
  const request = {
    method,
    originalUrl: path,
    headers: { authorization: 'Bearer signed-token' },
  };
  return {
    request,
    instance: new AuthGuard(
      { verifyAccessToken: () => ({ sub: 7, tipo, tv: 0 }) },
      {
        findOne: async () => ({
          id: 7,
          tipo,
          tokenVersion: 0,
          emailVerificado: true,
          mfaAtivo,
        }),
      },
      { exists: async () => accepted },
    ),
  };
}

function cadastroService({ falharAceite = false } = {}) {
  const gravados = [];
  let transacoes = 0;
  let entregas = 0;
  const usuarios = {
    findOne: async () => null,
    manager: {
      transaction: async (operation) => {
        transacoes++;
        return operation({
          getRepository(entity) {
            return {
              create: (value) => value,
              save: async (value) => {
                if (falharAceite && entity.name === 'TermoAceiteEntity') {
                  throw new Error('simulated transaction failure');
                }
                const saved = {
                  ...value,
                  id: entity.name === 'UsuarioEntity' ? 91 : gravados.length + 1,
                  tokenVersion: 0,
                  mfaAtivo: false,
                };
                gravados.push({ entity: entity.name, value: saved });
                return saved;
              },
            };
          },
        });
      },
    },
  };
  const service = new AuthService(
    {},
    {},
    usuarios,
    { exists: async () => true },
    {},
    {},
    { configured: () => true },
    {
      criarRegistro: (usuarioId, codigo, expiraEm) => ({
        usuarioId,
        codigo,
        expiraEm,
      }),
      entregarAgora: async () => {
        entregas++;
        return false;
      },
    },
    {},
    { hash: async () => 'scrypt$cadastro-seguro' },
    {
      createAccessToken: () => ({
        accessToken: 'signed-access-token',
        tokenType: 'Bearer',
        expiresIn: 3600,
      }),
    },
  );
  return {
    service,
    gravados,
    get transacoes() {
      return transacoes;
    },
    get entregas() {
      return entregas;
    },
  };
}

test('authenticated routes fail closed without acceptance of current terms', async () => {
  const { instance, request } = guard({ accepted: false });
  await assert.rejects(
    instance.canActivate(contextFor(request)),
    (error) =>
      error?.getStatus?.() === 403 &&
      error?.getResponse?.()?.code === 'TERMOS_NAO_ACEITOS',
  );
});

test('terms acceptance and privacy routes remain available without current acceptance', async () => {
  for (const path of ['/termos/aceites/me', '/privacidade/me/exportacao']) {
    const { instance, request } = guard({ accepted: false, path });
    assert.equal(await instance.canActivate(contextFor(request)), true);
  }
});

test('administrator protected routes fail closed until MFA is active', async () => {
  const { instance, request } = guard({
    accepted: true,
    tipo: 'administrador',
    path: '/admin/painel',
  });
  await assert.rejects(
    instance.canActivate(contextFor(request)),
    (error) => error?.getStatus?.() === 403 &&
      error?.getResponse?.()?.code === 'MFA_ADMIN_OBRIGATORIO',
  );
});

test('administrator with MFA can access protected routes', async () => {
  const { instance, request } = guard({
    accepted: true,
    tipo: 'administrador',
    mfaAtivo: true,
    path: '/admin/painel',
  });
  assert.equal(await instance.canActivate(contextFor(request)), true);
});

test('admin without MFA can only access logout and email verification endpoints', async () => {
  for (const [method, path] of [
    ['POST', '/auth/logout'],
    ['GET', '/auth/email/verificacao'],
    ['POST', '/auth/email/verificacao/enviar'],
    ['POST', '/auth/email/verificacao/confirmar'],
  ]) {
    const { instance, request } = guard({
      accepted: true,
      tipo: 'administrador',
      path,
      method,
    });
    assert.equal(await instance.canActivate(contextFor(request)), true);
  }
  const { instance, request } = guard({
    accepted: true,
    tipo: 'administrador',
    path: '/admin/painel',
  });
  await assert.rejects(instance.canActivate(contextFor(request)), (error) => error?.getStatus?.() === 403);
});

test('e-mail outbox encrypts verification codes at rest and detects tampering', () => {
  const previous = process.env.EMAIL_OUTBOX_ENCRYPTION_KEY;
  process.env.EMAIL_OUTBOX_ENCRYPTION_KEY =
    'test-only-outbox-key-with-more-than-32-characters';
  try {
    const encrypted = criptografarCodigoOutbox('482901');
    assert.equal(encrypted.includes('482901'), false);
    assert.equal(descriptografarCodigoOutbox(encrypted), '482901');
    assert.throws(() =>
      descriptografarCodigoOutbox(`${encrypted.slice(0, -1)}x`),
    );
  } finally {
    if (previous === undefined) delete process.env.EMAIL_OUTBOX_ENCRYPTION_KEY;
    else process.env.EMAIL_OUTBOX_ENCRYPTION_KEY = previous;
  }
});

test('registration commits user, current terms, verification and outbox together', async () => {
  const fixture = cadastroService();
  const response = await fixture.service.cadastro({
    nome: 'Cliente Seguro',
    email: 'cliente-seguro@example.invalid',
    senha: 'SenhaSegura123!',
    tipo: 'cliente',
    aceitouTermos: true,
    versaoTermos: '2026-10-24.v5',
  });

  assert.equal(fixture.transacoes, 1);
  assert.deepEqual(
    fixture.gravados.map((item) => item.entity),
    [
      'UsuarioEntity',
      'TermoAceiteEntity',
      'UsuarioEmailVerificacaoEntity',
      'EmailOutboxEntity',
    ],
  );
  assert.equal(fixture.entregas, 1);
  assert.equal(response.emailVerificationRequired, true);
  assert.equal(response.emailVerificationSent, false);
  assert.equal(response.usuario.termosAceitos, true);
});

test('registration does not attempt delivery when its transaction fails', async () => {
  const fixture = cadastroService({ falharAceite: true });
  await assert.rejects(
    fixture.service.cadastro({
      nome: 'Cliente Seguro',
      email: 'falha-transacao@example.invalid',
      senha: 'SenhaSegura123!',
      tipo: 'cliente',
      aceitouTermos: true,
      versaoTermos: '2026-10-24.v5',
    }),
    /simulated transaction failure/,
  );
  assert.equal(fixture.transacoes, 1);
  assert.equal(fixture.entregas, 0);
});
