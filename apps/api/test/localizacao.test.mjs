import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import { LocalizacaoService } from '../dist/localizacao/localizacao.service.js';

const originalFetch = globalThis.fetch;
const originalGoogleKey = process.env.GOOGLE_MAPS_SERVER_API_KEY;

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalGoogleKey === undefined) {
    delete process.env.GOOGLE_MAPS_SERVER_API_KEY;
  } else {
    process.env.GOOGLE_MAPS_SERVER_API_KEY = originalGoogleKey;
  }
});

test('consulta de CEP valida formato antes de chamar servico externo', async () => {
  let chamado = false;
  globalThis.fetch = async () => {
    chamado = true;
    throw new Error('nao deveria chamar');
  };

  await assert.rejects(
    new LocalizacaoService().consultarCep('123'),
    (error) => error?.getResponse?.().code === 'CEP_INVALIDO',
  );
  assert.equal(chamado, false);
});

test('consulta ViaCEP preenche regiao mesmo sem chave do Google', async () => {
  delete process.env.GOOGLE_MAPS_SERVER_API_KEY;
  globalThis.fetch = async (url) => {
    assert.equal(String(url), 'https://viacep.com.br/ws/01001000/json/');
    return new Response(
      JSON.stringify({
        cep: '01001-000',
        logradouro: 'Praca da Se',
        complemento: '',
        bairro: 'Se',
        localidade: 'Sao Paulo',
        uf: 'SP',
        regiao: 'Sudeste',
        ibge: '3550308',
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };

  const endereco = await new LocalizacaoService().consultarCep('01001-000');
  assert.equal(endereco.cep, '01001000');
  assert.equal(endereco.cidade, 'Sao Paulo');
  assert.equal(endereco.uf, 'SP');
  assert.equal(endereco.latitude, null);
  assert.equal(endereco.longitude, null);
});
