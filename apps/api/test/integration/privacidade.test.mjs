import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

const url = process.env.CONECTALAR_TEST_API_URL;

test(
  'exportacao e exclusao LGPD invalidam a conta sem expor segredos',
  { skip: !url },
  async () => {
    assert.ok(
      ['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname),
      'O teste destrutivo so pode usar uma API local.',
    );
    const suffix = randomUUID().slice(0, 8);
    const email = `lgpd.${suffix}@conectalar.local`;
    const senha = 'ConectaLarTeste123!';

    async function request(method, path, token, body, expectedStatus) {
      const response = await fetch(`${url.replace(/\/$/, '')}/${path}`, {
        method,
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const data = await response.json();
      assert.equal(
        response.status,
        expectedStatus,
        `${method} ${path}: ${JSON.stringify(data)}`,
      );
      return data;
    }

    const cadastro = await request(
      'POST',
      'auth/cadastro',
      null,
      {
        nome: 'Titular LGPD',
        email,
        senha,
        tipo: 'cliente',
      },
      201,
    );
    const token = cadastro.token.accessToken;
    assert.ok(cadastro.devCode, 'Ative EXPOSE_EMAIL_VERIFICATION_CODE somente na API local de teste.');
    await request('POST', 'auth/email/verificacao/confirmar', token,
      { codigo: cadastro.devCode }, 201);

    await request(
      'POST',
      'privacidade/me/exportacao',
      token,
      { senhaAtual: 'SenhaIncorreta123!' },
      401,
    );
    const exportacao = await request(
      'POST',
      'privacidade/me/exportacao',
      token,
      { senhaAtual: senha },
      201,
    );
    assert.equal(exportacao.dados.conta.email, email);
    assert.equal(exportacao.dados.conta.nome, 'Titular LGPD');
    const exportacaoSerializada = JSON.stringify(exportacao);
    for (const segredo of [
      'senhaHash',
      'senha_hash',
      'mfaSecretEncrypted',
      'tokenHash',
      'codigoHash',
      token,
      senha,
    ]) {
      assert.doesNotMatch(exportacaoSerializada, new RegExp(segredo));
    }

    await request(
      'POST',
      'privacidade/me/exclusao',
      token,
      { senhaAtual: senha, confirmacao: 'excluir' },
      400,
    );
    const exclusao = await request(
      'POST',
      'privacidade/me/exclusao',
      token,
      { senhaAtual: senha, confirmacao: 'EXCLUIR' },
      201,
    );
    assert.equal(exclusao.contaExcluida, true);

    await request('GET', 'clientes/me', token, undefined, 401);
    await request(
      'POST',
      'auth/login',
      null,
      { email, senha },
      401,
    );
  },
);
