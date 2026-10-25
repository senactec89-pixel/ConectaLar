import assert from 'node:assert/strict';
import test from 'node:test';
import { IdZapSignProvider } from '../dist/verificacao/id-zapsign.provider.js';
import { HabilitacaoService } from '../dist/verificacao/habilitacao.service.js';
import { invalidarVerificacoesTelefone } from '../dist/verificacao/telefone-verificacao.util.js';

const apiKey = 'test-phone-provider-key';
const externalRef = 'phone-verification-test';
const reference = 'val_2W7HJ9RC4XKQ0ZB58NDT3PMFY6';

function provider(t, enabled = 'false') {
  const previousEnabled = process.env.ID_ZAPSIGN_PHONE_ENABLED;
  const previousKey = process.env.ID_ZAPSIGN_API_KEY;
  process.env.ID_ZAPSIGN_PHONE_ENABLED = enabled;
  process.env.ID_ZAPSIGN_API_KEY = apiKey;
  t.after(() => {
    if (previousEnabled === undefined) delete process.env.ID_ZAPSIGN_PHONE_ENABLED;
    else process.env.ID_ZAPSIGN_PHONE_ENABLED = previousEnabled;
    if (previousKey === undefined) delete process.env.ID_ZAPSIGN_API_KEY;
    else process.env.ID_ZAPSIGN_API_KEY = previousKey;
  });
  return new IdZapSignProvider();
}

const response = (body, status = 200) => new Response(JSON.stringify(body), { status });
const validation = (overrides = {}) => ({
  object: 'validation',
  id: reference,
  type: 'phone_ownership',
  status: 'pending',
  result: null,
  reason_code: null,
  external_id: externalRef,
  validation_url: null,
  expires_at: '2026-10-25T12:10:00.000Z',
  resolved_at: null,
  attempts_remaining: 3,
  ...overrides,
});

test('posse por WhatsApp desabilitada nunca chama o fornecedor', async (t) => {
  const zap = provider(t);
  const fetch = t.mock.method(globalThis, 'fetch', async () => assert.fail('nao deveria chamar fetch'));
  assert.equal(zap.telefoneDisponivel, false);
  await assert.rejects(zap.iniciarPosseTelefone({
    telefoneE164: '+5511999998888', referenciaExterna: externalRef, chaveIdempotencia: 'start-key',
  }), (error) => error.getStatus?.() === 503);
  assert.equal(fetch.mock.callCount(), 0);
});

test('rota de inicio falha fechada sem chave/flag e nao aciona fornecedor', async (t) => {
  const previousEnabled = process.env.ID_ZAPSIGN_PHONE_ENABLED;
  const previousKey = process.env.ID_ZAPSIGN_API_KEY;
  process.env.ID_ZAPSIGN_PHONE_ENABLED = 'false';
  process.env.ID_ZAPSIGN_API_KEY = apiKey;
  t.after(() => {
    if (previousEnabled === undefined) delete process.env.ID_ZAPSIGN_PHONE_ENABLED;
    else process.env.ID_ZAPSIGN_PHONE_ENABLED = previousEnabled;
    if (previousKey === undefined) delete process.env.ID_ZAPSIGN_API_KEY;
    else process.env.ID_ZAPSIGN_API_KEY = previousKey;
  });
  const fetch = t.mock.method(globalThis, 'fetch', async () => assert.fail('nao deveria chamar fetch'));
  const service = new HabilitacaoService({}, {}, undefined, new IdZapSignProvider(), undefined);
  const profissional = { id: 8, tipo: 'profissional' };
  await assert.rejects(service.iniciarTelefone(profissional, { consentimento: true }),
    (error) => error.getStatus?.() === 503 && error.getResponse?.().code === 'VERIFICACAO_TELEFONE_INDISPONIVEL');
  await assert.rejects(service.iniciarTelefone(profissional, { consentimento: false }),
    (error) => error.getStatus?.() === 400);
  assert.equal(fetch.mock.callCount(), 0);
});

test('mudanca de telefone invalida estados anteriores sem gravar OTP', async () => {
  let update;
  await invalidarVerificacoesTelefone({
    async update(...args) { update = args; },
  }, 42);
  assert.equal(update[0].name, 'ProfissionalTelefoneVerificacaoEntity');
  assert.equal(update[1].usuarioId, 42);
  assert.deepEqual(update[2], {
    estado: 'invalidada',
    resolvidaEm: update[2].resolvidaEm,
    tentativaEmAndamento: false,
  });
  assert.ok(update[2].resolvidaEm instanceof Date);
  assert.equal(Object.hasOwn(update[2], 'codigo'), false);
});

test('cria posse de telefone com consentimento, E.164 e idempotencia', async (t) => {
  const zap = provider(t, 'true');
  let request;
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    request = { url: String(url), init };
    return response(validation());
  });
  const result = await zap.iniciarPosseTelefone({
    telefoneE164: '+5511999998888', referenciaExterna: externalRef, chaveIdempotencia: 'start-key',
  });
  assert.equal(request.url, 'https://api.id.zapsign.com.br/v1/validations/phone-ownership');
  assert.equal(request.init.method, 'POST');
  assert.equal(request.init.headers.Authorization, `Bearer ${apiKey}`);
  assert.equal(request.init.headers['Idempotency-Key'], 'start-key');
  assert.deepEqual(JSON.parse(request.init.body), {
    phone: '+5511999998888', consent: true, external_id: externalRef,
  });
  assert.deepEqual(result, {
    referencia: reference,
    tentativasRestantes: 3,
    expiraEm: new Date('2026-10-25T12:10:00.000Z'),
  });
});

test('confirma código sem guardar e mapeia somente estados reconhecidos', async (t) => {
  const zap = provider(t, 'true');
  const outcomes = [
    validation({ attempts_remaining: 2 }),
    validation({ status: 'completed', result: 'passed', attempts_remaining: 0, resolved_at: '2026-10-25T12:02:00Z' }),
    validation({ status: 'completed', result: 'not_passed', attempts_remaining: 0 }),
    validation({ status: 'expired', attempts_remaining: 0 }),
    validation({ status: 'failed', attempts_remaining: 0 }),
  ];
  const requests = [];
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    requests.push({ url: String(url), init });
    return response(outcomes.shift());
  });
  const submit = (key) => zap.confirmarPosseTelefone({
    referencia: reference, referenciaExterna: externalRef, codigo: '012345', chaveIdempotencia: key,
  });

  assert.equal((await submit('attempt-1')).status, 'pendente');
  const confirmed = await submit('attempt-2');
  assert.equal(confirmed.status, 'confirmada');
  assert.equal(confirmed.resolvidaEm.toISOString(), '2026-10-25T12:02:00.000Z');
  assert.equal((await submit('attempt-3')).status, 'revisao_necessaria');
  assert.equal((await submit('attempt-4')).status, 'expirada');
  assert.equal((await submit('attempt-5')).status, 'revisao_necessaria');
  assert.equal(requests[0].url, `https://api.id.zapsign.com.br/v1/validations/${reference}/verify`);
  assert.deepEqual(JSON.parse(requests[0].init.body), { code: '012345' });
  assert.equal(requests[0].init.headers['Idempotency-Key'], 'attempt-1');
});

test('recusa resposta de telefone com referencia ou tipo divergente', async (t) => {
  const zap = provider(t, 'true');
  const responses = [validation({ external_id: 'another-user' }), validation({ type: 'liveness_document_match' })];
  t.mock.method(globalThis, 'fetch', async () => response(responses.shift()));
  for (let i = 0; i < 2; i += 1) {
    await assert.rejects(zap.iniciarPosseTelefone({
      telefoneE164: '+5511999998888', referenciaExterna: externalRef, chaveIdempotencia: `start-${i}`,
    }), (error) => error.getStatus?.() === 503);
  }
});

test('falha HTTP do fornecedor nao expoe resposta ou conteudo de autenticacao', async (t) => {
  const zap = provider(t, 'true');
  t.mock.method(globalThis, 'fetch', async () => response({ secret: 'private provider response' }, 402));
  await assert.rejects(zap.confirmarPosseTelefone({
    referencia: reference, referenciaExterna: externalRef, codigo: '1234', chaveIdempotencia: 'verify-key',
  }), (error) => error.getStatus?.() === 503 && !JSON.stringify(error.getResponse()).includes('private provider response'));
});
