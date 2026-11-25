import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import {
  criarMessagingFcm,
  hashToken,
  PushNotificacoesService,
} from '../dist/notificacoes/push-notificacoes.service.js';

const originalFcm = {
  enabled: process.env.FCM_ENABLED,
  projectId: process.env.FCM_PROJECT_ID,
  clientEmail: process.env.FCM_CLIENT_EMAIL,
  privateKey: process.env.FCM_PRIVATE_KEY,
};

afterEach(() => {
  for (const [key, value] of Object.entries({
    FCM_ENABLED: originalFcm.enabled,
    FCM_PROJECT_ID: originalFcm.projectId,
    FCM_CLIENT_EMAIL: originalFcm.clientEmail,
    FCM_PRIVATE_KEY: originalFcm.privateKey,
  })) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

function fakeRepository({ devices = [], count = devices.length } = {}) {
  const calls = { upserts: [], deletes: [], finds: 0 };
  return {
    calls,
    async findOne() { return null; },
    async count() { return count; },
    async upsert(value, conflict) { calls.upserts.push({ value, conflict }); },
    async find() { calls.finds += 1; return devices; },
    async delete(where) { calls.deletes.push(where); },
  };
}

test('registra token por hash e nao devolve o token ao cliente', async () => {
  const repo = fakeRepository();
  const service = new PushNotificacoesService(repo, null);
  const token = 'fcm_registration_token_for_test_123456789';

  const response = await service.registrar(
    { id: 42, tipo: 'cliente' },
    { token, plataforma: 'android' },
  );

  assert.deepEqual(response, { ok: true });
  assert.deepEqual(repo.calls.upserts[0].conflict, ['tokenHash']);
  assert.equal(repo.calls.upserts[0].value.usuarioId, 42);
  assert.equal(repo.calls.upserts[0].value.token, token);
  assert.equal(repo.calls.upserts[0].value.tokenHash, hashToken(token));
});

test('rejeita token malformado e impede crescimento ilimitado de dispositivos', async () => {
  const repo = fakeRepository({ count: 10 });
  const service = new PushNotificacoesService(repo, null);

  await assert.rejects(
    service.registrar({ id: 1, tipo: 'cliente' }, { token: 'bad', plataforma: 'android' }),
    (error) => error?.getResponse?.().code === 'DISPOSITIVO_PUSH_INVALIDO',
  );
  await assert.rejects(
    service.registrar(
      { id: 1, tipo: 'cliente' },
      { token: 'fcm_registration_token_for_test_123456789', plataforma: 'android' },
    ),
    (error) => error?.getResponse?.().code === 'LIMITE_DISPOSITIVOS_PUSH',
  );
  assert.equal(repo.calls.upserts.length, 0);
});

test('revoga somente o token que pertence a conta autenticada', async () => {
  const repo = fakeRepository();
  const service = new PushNotificacoesService(repo, null);
  const token = 'fcm_registration_token_for_test_123456789';

  await service.revogar({ id: 9, tipo: 'profissional' }, { token });

  assert.equal(repo.calls.deletes[0].usuarioId, 9);
  assert.equal(repo.calls.deletes[0].tokenHash, hashToken(token));
});

test('remove tokens rejeitados pelo FCM sem expor o valor no log', async () => {
  const token = 'fcm_registration_token_for_test_123456789';
  const repo = fakeRepository({
    devices: [{ id: 2, token, tokenHash: hashToken(token) }],
  });
  let sent;
  const messaging = {
    async sendEachForMulticast(message) {
      sent = message;
      return {
        failureCount: 1,
        responses: [{
          success: false,
          error: { code: 'messaging/registration-token-not-registered' },
        }],
      };
    },
  };
  const service = new PushNotificacoesService(repo, messaging);

  await service.enviar({
    id: 88,
    usuarioId: 7,
    tipo: 'solicitacao_criada',
    titulo: 'Nova solicitacao',
    mensagem: 'Voce recebeu uma solicitacao.',
    recursoTipo: 'solicitacao',
    recursoId: 22,
  });

  assert.equal(sent.data.notificationId, '88');
  assert.equal(sent.data.resourceId, '22');
  assert.equal(sent.notification.body, 'Voce recebeu uma solicitacao.');
  assert.equal(repo.calls.deletes[0].usuarioId, 7);
});

test('FCM fica desligado por padrao e exige segredos quando habilitado', () => {
  delete process.env.FCM_ENABLED;
  assert.equal(criarMessagingFcm(), null);

  process.env.FCM_ENABLED = 'true';
  delete process.env.FCM_PROJECT_ID;
  delete process.env.FCM_CLIENT_EMAIL;
  delete process.env.FCM_PRIVATE_KEY;
  assert.throws(() => criarMessagingFcm(), /FCM_CONFIGURATION_INCOMPLETE/);
});
