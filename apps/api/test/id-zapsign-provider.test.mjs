import assert from 'node:assert/strict';
import test from 'node:test';
import { IdZapSignProvider } from '../dist/verificacao/id-zapsign.provider.js';

const apiKey = 'test-only-provider-key';
const externalRef = 'external-test-ref';
const validUrl = 'https://id.zapsign.com.br/validate/val_Abc123';

function prepare(t, { enabled = 'true', key = apiKey } = {}) {
  const previousEnabled = process.env.ID_ZAPSIGN_ENABLED;
  const previousKey = process.env.ID_ZAPSIGN_API_KEY;
  process.env.ID_ZAPSIGN_ENABLED = enabled;
  if (key === undefined) delete process.env.ID_ZAPSIGN_API_KEY;
  else process.env.ID_ZAPSIGN_API_KEY = key;
  t.after(() => {
    if (previousEnabled === undefined) delete process.env.ID_ZAPSIGN_ENABLED;
    else process.env.ID_ZAPSIGN_ENABLED = previousEnabled;
    if (previousKey === undefined) delete process.env.ID_ZAPSIGN_API_KEY;
    else process.env.ID_ZAPSIGN_API_KEY = previousKey;
  });
  return new IdZapSignProvider();
}

function providerResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function pendingValidation(overrides = {}) {
  return {
    object: 'validation',
    id: 'val_Abc123',
    type: 'liveness_document_match',
    external_id: externalRef,
    status: 'pending',
    result: null,
    validation_url: validUrl,
    expires_at: '2026-11-01T12:00:00.000Z',
    ...overrides,
  };
}

test('ID ZapSign fica indisponivel sem ativacao e chave, e nao chama o fornecedor', async (t) => {
  const provider = prepare(t, { enabled: 'false' });
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    assert.fail('fetch nao deve ser chamado com integracao desativada');
  });

  assert.equal(provider.disponivel, false);
  await assert.rejects(provider.iniciar({ referenciaExterna: externalRef, chaveIdempotencia: 'idem' }),
    (error) => error.getStatus?.() === 503 && error.getResponse?.().code === 'VERIFICACAO_IDENTIDADE_INDISPONIVEL');
  assert.equal(fetch.mock.callCount(), 0);
});

test('cria verificacao com consentimento, idempotencia e URL oficial validada', async (t) => {
  const provider = prepare(t);
  let request;
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    request = { url: String(url), init };
    return providerResponse(pendingValidation());
  });

  const result = await provider.iniciar({ referenciaExterna: externalRef, chaveIdempotencia: 'idem-123' });

  assert.deepEqual(result, {
    referencia: 'val_Abc123',
    url: validUrl,
    expiraEm: new Date('2026-11-01T12:00:00.000Z'),
  });
  assert.equal(request.url, 'https://api.id.zapsign.com.br/v1/validations/liveness-document-match');
  assert.equal(request.init.method, 'POST');
  assert.equal(request.init.headers.Authorization, `Bearer ${apiKey}`);
  assert.equal(request.init.headers['Idempotency-Key'], 'idem-123');
  assert.deepEqual(JSON.parse(request.init.body), { consent: true, external_id: externalRef });
  assert.ok(request.init.signal instanceof AbortSignal);
});

test('consulta vincula ID, referencia externa e tipo antes de aceitar resultado', async (t) => {
  const provider = prepare(t);
  const queue = [
    pendingValidation({ status: 'completed', result: 'passed', resolved_at: '2026-10-25T12:00:00.000Z' }),
    pendingValidation({ status: 'completed', result: 'not_passed' }),
    pendingValidation({ status: 'completed', result: 'unknown' }),
    pendingValidation({ status: 'expired' }),
    pendingValidation({ status: 'unexpected' }),
  ];
  t.mock.method(globalThis, 'fetch', async () => providerResponse(queue.shift()));

  const confirmed = await provider.consultar('val_Abc123', externalRef);
  assert.equal(confirmed.status, 'confirmada');
  assert.equal(confirmed.url, null);
  assert.equal(confirmed.resolvidaEm.toISOString(), '2026-10-25T12:00:00.000Z');
  assert.equal((await provider.consultar('val_Abc123', externalRef)).status, 'revisao_necessaria');
  assert.equal((await provider.consultar('val_Abc123', externalRef)).status, 'revisao_necessaria');
  assert.equal((await provider.consultar('val_Abc123', externalRef)).status, 'expirada');
  assert.equal((await provider.consultar('val_Abc123', externalRef)).status, 'revisao_necessaria');
});

test('resultado pendente mantem somente URL oficial permitida', async (t) => {
  const provider = prepare(t);
  t.mock.method(globalThis, 'fetch', async () => providerResponse(pendingValidation()));

  const result = await provider.consultar('val_Abc123', externalRef);

  assert.equal(result.status, 'pendente');
  assert.equal(result.url, validUrl);
});

test('recusa URL nao confiavel, correlacao divergente e payload malformado', async (t) => {
  const provider = prepare(t);
  const responses = [
    pendingValidation({ validation_url: 'https://attacker.example/validate/val_Abc123' }),
    pendingValidation({ validation_url: 'http://id.zapsign.com.br/validate/val_Abc123' }),
    pendingValidation({ external_id: 'other-ref' }),
    pendingValidation({ type: 'other-validation' }),
    pendingValidation({ id: 'bad id' }),
    [],
  ];
  t.mock.method(globalThis, 'fetch', async () => providerResponse(responses.shift()));
  const genericUnavailable = (error) => error.getStatus?.() === 503 &&
    error.getResponse?.().code === 'VERIFICACAO_IDENTIDADE_INDISPONIVEL';

  for (let index = 0; index < 2; index += 1) {
    await assert.rejects(provider.iniciar({ referenciaExterna: externalRef, chaveIdempotencia: 'idem' }), genericUnavailable);
  }
  for (let index = 0; index < 4; index += 1) {
    await assert.rejects(provider.consultar('val_Abc123', externalRef), genericUnavailable);
  }
});

test('falhas HTTP, rede e JSON nao revelam detalhes do fornecedor', async (t) => {
  const provider = prepare(t);
  const fetch = t.mock.method(globalThis, 'fetch', async () => providerResponse({ message: 'provider secret detail' }, 500));
  await assert.rejects(provider.iniciar({ referenciaExterna: externalRef, chaveIdempotencia: 'idem' }),
    (error) => error.getStatus?.() === 503 && !JSON.stringify(error.getResponse()).includes('provider secret detail'));

  fetch.mock.mockImplementationOnce(async () => { throw new Error('private network detail'); });
  await assert.rejects(provider.consultar('val_Abc123', externalRef),
    (error) => error.getStatus?.() === 503 && !JSON.stringify(error.getResponse()).includes('private network detail'));
});
