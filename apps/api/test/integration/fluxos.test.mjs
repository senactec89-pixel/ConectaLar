import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

// Run only against a local API backed by a disposable test database.
const url = process.env.CONECTALAR_TEST_API_URL;

test(
  'search and favorites work while pending professionals cannot receive requests',
  { skip: !url },
  async () => {
    assert.ok(
      ['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname),
      'Integration tests must target a local API.',
    );

    const suffix = randomUUID().replaceAll('-', '').slice(0, 10);
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

    async function cadastro(tipo) {
      const cadastro = await request(
        'POST',
        'auth/cadastro',
        null,
        {
          nome: `Teste ${tipo} ${suffix}`,
          email: `${tipo}.${suffix}@conectalar.local`,
          senha,
          tipo,
          aceitouTermos: true,
          versaoTermos: '2026-10-24.v5',
        },
        201,
      );
      assert.ok(
        cadastro.devCode,
        'Enable EXPOSE_EMAIL_VERIFICATION_CODE only on the local test API.',
      );
      await request(
        'POST',
        'auth/email/verificacao/confirmar',
        cadastro.token.accessToken,
        { codigo: cadastro.devCode },
        201,
      );
      return cadastro.token.accessToken;
    }

    const cliente = await cadastro('cliente');
    const profissionalToken = await cadastro('profissional');
    const perfil = await request(
      'PUT',
      'profissionais/me',
      profissionalToken,
      {
        descricao: 'Perfil ficticio para testar busca e seguranca.',
        bairro: 'Centro',
        cidade: 'Sao Paulo',
        uf: 'SP',
        servicos: [{ nome: 'Servico de teste', duracaoMinutos: 60 }],
      },
      200,
    );
    const profissionalId = perfil.profissional.id;
    const servicoId = perfil.profissional.servicos[0].id;

    const busca = await request(
      'GET',
      'profissionais?bairro=Centro&pagina=1&limite=1',
      null,
      undefined,
      200,
    );
    assert.equal(busca.paginacao.pagina, 1);
    assert.equal(busca.paginacao.limite, 1);
    assert.ok(busca.profissionais.some((item) => item.id === profissionalId));

    await request(
      'POST',
      `clientes/me/favoritos/${profissionalId}`,
      cliente,
      undefined,
      201,
    );
    const estadoFavorito = await request(
      'GET',
      `clientes/me/favoritos/${profissionalId}`,
      cliente,
      undefined,
      200,
    );
    assert.equal(estadoFavorito.favorito, true);

    const favoritos = await request(
      'GET',
      'clientes/me/favoritos?pagina=1&limite=1',
      cliente,
      undefined,
      200,
    );
    assert.equal(favoritos.paginacao.pagina, 1);
    assert.equal(favoritos.paginacao.limite, 1);
    assert.ok(favoritos.favoritos.some((item) => item.profissional.id === profissionalId));

    const dataServico = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
    const endereco = await request(
      'POST',
      'clientes/me/enderecos',
      cliente,
      {
        apelido: 'Casa de teste',
        logradouro: 'Rua de Teste',
        numero: '10',
        bairro: 'Centro',
        cidade: 'Sao Paulo',
        uf: 'SP',
        principal: true,
      },
      201,
    );
    const bloqueio = await request(
      'POST',
      'solicitacoes',
      cliente,
      {
        profissionalId,
        servicoId,
        enderecoId: endereco.endereco.id,
        descricao: 'Solicitacao ficticia para confirmar o bloqueio seguro.',
        bairroAtendimento: 'Centro',
        dataServico,
        horarioServico: '10:00',
      },
      409,
    );
    assert.equal(bloqueio.code, 'PROFISSIONAL_HABILITACAO_PENDENTE');

    const pedidos = await request(
      'GET',
      'solicitacoes/me?pagina=1&limite=20',
      cliente,
      undefined,
      200,
    );
    assert.equal(pedidos.solicitacoes.length, 0);
  },
);
