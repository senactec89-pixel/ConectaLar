import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AuthService } from '../dist/auth/auth.service.js';
import {
  GoogleIdentityService,
  googleOAuthClientIds,
} from '../dist/auth/google-identity.service.js';

const identity = {
  subject: 'google-subject-123',
  email: 'pessoa@gmail.com',
  name: 'Pessoa Google',
  emailAuthoritative: true,
};

function authService({ users, googleIdentity = identity, acceptedTerms } = {}) {
  const userRepository = users ?? {
    findOne: async () => null,
    manager: {
      transaction: async (operation) =>
        operation({
          getRepository(entity) {
            if (entity.name === 'UsuarioEntity') {
              return {
                create: (value) => value,
                save: async (value) => ({ id: 81, tokenVersion: 0, ...value }),
              };
            }
            return {
              create: (value) => value,
              save: async (value) => {
                acceptedTerms?.push(value);
                return value;
              },
            };
          },
        }),
    },
  };
  return new AuthService(
    {},
    {},
    userRepository,
    { verify: async () => googleIdentity },
    {},
    {},
    { hash: async () => 'scrypt$google-random' },
    {
      createAccessToken: () => ({
        accessToken: 'conectalar-token',
        tokenType: 'Bearer',
        expiresIn: 3600,
      }),
      createMfaChallengeToken: () => ({
        mfaToken: 'mfa-challenge',
        expiresIn: 300,
      }),
    },
  );
}

test('Google OAuth audiences are trimmed and deduplicated', () => {
  assert.deepEqual(
    googleOAuthClientIds({ GOOGLE_OAUTH_CLIENT_IDS: 'web-1, web-2,web-1' }),
    ['web-1', 'web-2'],
  );
  assert.deepEqual(
    googleOAuthClientIds({ GOOGLE_WEB_CLIENT_ID: 'single-web-client' }),
    ['single-web-client'],
  );
});

test('Google token verification fails closed when OAuth is not configured', async () => {
  const previousList = process.env.GOOGLE_OAUTH_CLIENT_IDS;
  const previousWeb = process.env.GOOGLE_WEB_CLIENT_ID;
  delete process.env.GOOGLE_OAUTH_CLIENT_IDS;
  delete process.env.GOOGLE_WEB_CLIENT_ID;
  try {
    await assert.rejects(
      new GoogleIdentityService().verify('untrusted-token'),
      (error) => error?.getStatus?.() === 503,
    );
  } finally {
    if (previousList === undefined) delete process.env.GOOGLE_OAUTH_CLIENT_IDS;
    else process.env.GOOGLE_OAUTH_CLIENT_IDS = previousList;
    if (previousWeb === undefined) delete process.env.GOOGLE_WEB_CLIENT_ID;
    else process.env.GOOGLE_WEB_CLIENT_ID = previousWeb;
  }
});

test('first Google access asks for account type before creating data', async () => {
  const result = await authService().loginGoogle({ idToken: 'valid-token' });

  assert.equal(result.cadastroNecessario, true);
  assert.deepEqual(result.perfilGoogle, {
    nome: identity.name,
    email: identity.email,
  });
  assert.equal(result.token, undefined);
});

test('new Google account records current terms and starts verified', async () => {
  const acceptedTerms = [];
  const result = await authService({ acceptedTerms }).loginGoogle({
    idToken: 'valid-token',
    tipo: 'profissional',
    aceitouTermos: true,
    senha: 'SenhaGoogle123!',
  });

  assert.equal(result.contaCriada, true);
  assert.equal(result.usuario.tipo, 'profissional');
  assert.equal(result.usuario.emailVerificado, true);
  assert.equal(result.usuario.googleVinculado, true);
  assert.equal(result.token.accessToken, 'conectalar-token');
  assert.equal(acceptedTerms.length, 1);
  assert.equal(acceptedTerms[0].usuarioId, 81);
  assert.equal(acceptedTerms[0].canal, 'google');
});

test('new Google account requires a strong ConectaLar recovery password', async () => {
  await assert.rejects(
    authService().loginGoogle({
      idToken: 'valid-token',
      tipo: 'cliente',
      aceitouTermos: true,
    }),
    (error) => error?.getStatus?.() === 400,
  );
});

test('existing authoritative Google e-mail is linked without changing its role', async () => {
  const existing = {
    id: 12,
    nome: 'Conta existente',
    email: identity.email,
    emailVerificado: false,
    googleSub: null,
    telefone: null,
    fotoPerfil: null,
    tipo: 'cliente',
    ativo: true,
    tokenVersion: 0,
    mfaAtivo: false,
  };
  const users = {
    findOne: async ({ where }) => ('googleSub' in where ? null : existing),
    save: async (value) => value,
  };

  const result = await authService({ users }).loginGoogle({
    idToken: 'valid-token',
  });

  assert.equal(result.contaVinculada, true);
  assert.equal(result.usuario.tipo, 'cliente');
  assert.equal(existing.googleSub, identity.subject);
  assert.equal(existing.emailVerificado, true);
});

test('administrator linked to Google still receives an MFA challenge', async () => {
  const admin = {
    id: 1,
    nome: 'Admin',
    email: 'admin@gmail.com',
    emailVerificado: true,
    googleSub: identity.subject,
    telefone: null,
    fotoPerfil: null,
    tipo: 'administrador',
    ativo: true,
    tokenVersion: 3,
    mfaAtivo: true,
  };
  const users = { findOne: async () => admin };

  const result = await authService({ users }).loginGoogle({
    idToken: 'valid-token',
  });

  assert.equal(result.mfaRequired, true);
  assert.equal(result.mfaToken, 'mfa-challenge');
  assert.equal(result.token, undefined);
});
