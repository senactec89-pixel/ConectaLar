import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

const url = process.env.CONECTALAR_TEST_API_URL;

test(
  'availability remains visible but pending professionals cannot book or receive requests',
  { skip: !url },
  async () => {
    assert.ok(
      ['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname),
      'Integration tests must target a local API.',
    );

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

    async function register(tipo) {
      const suffix = randomUUID().replaceAll('-', '').slice(0, 10);
      const cadastro = await request(
        'POST',
        'auth/cadastro',
        null,
        {
          nome: `Agenda ${tipo} ${suffix}`,
          tipo,
          senha: 'ConectaLarTeste123!',
          email: `agenda.${tipo}.${suffix}@conectalar.local`,
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

    const cliente = await register('cliente');
    const profissionalToken = await register('profissional');
    const categorias = (
      await request('GET', 'categorias', null, undefined, 200)
    ).categorias;
    assert.ok(categorias.length > 0);
    const endereco = await request(
      'POST',
      'clientes/me/enderecos',
      cliente,
      {
        apelido: 'Teste',
        logradouro: 'Rua de Teste',
        numero: '1',
        bairro: 'Centro',
        cidade: 'Belo Horizonte',
        uf: 'MG',
        principal: true,
      },
      201,
    );
    const perfil = await request(
      'PUT',
      'profissionais/me',
      profissionalToken,
      {
        descricao: 'Servico ficticio para testar disponibilidade.',
        bairro: 'Centro',
        cidade: 'Belo Horizonte',
        uf: 'MG',
        servicos: [
          {
            nome: 'Servico de duas horas',
            categoriaId: categorias[0].id,
            duracaoMinutos: 120,
          },
        ],
      },
      200,
    );
    const profissionalId = perfil.profissional.id;
    const servico = perfil.profissional.servicos[0];
    await request(
      'PUT',
      'profissionais/me/disponibilidade',
      profissionalToken,
      {
        disponibilidades: Array.from({ length: 7 }, (_, diaSemana) => ({
          diaSemana,
          horaInicio: '08:00',
          horaFim: '18:00',
        })),
      },
      200,
    );

    const dataServico = `${new Date().getUTCFullYear() + 1}-10-18`;
    const horarios = await request(
      'GET',
      `profissionais/${profissionalId}/horarios?data=${dataServico}&servicoId=${servico.id}`,
      null,
      undefined,
      200,
    );
    assert.equal(horarios.duracaoMinutos, 120);
    assert.equal(horarios.fusoHorario, 'America/Sao_Paulo');
    assert.ok(horarios.intervalos.length > 0);

    const bloqueio = await request(
      'POST',
      'solicitacoes',
      cliente,
      {
        profissionalId,
        servicoId: servico.id,
        enderecoId: endereco.endereco.id,
        descricao: 'Pedido ficticio para verificar a regra de habilitacao.',
        bairroAtendimento: 'Centro',
        dataServico,
        horarioServico: '10:00',
        duracaoMinutos: 1,
      },
      409,
    );
    assert.equal(bloqueio.code, 'PROFISSIONAL_HABILITACAO_PENDENTE');

    const [pedidos, agenda] = await Promise.all([
      request('GET', 'solicitacoes/me?pagina=1&limite=20', cliente, undefined, 200),
      request(
        'GET',
        `profissionais/me/agenda?mes=${dataServico.slice(0, 7)}`,
        profissionalToken,
        undefined,
        200,
      ),
    ]);
    assert.equal(pedidos.solicitacoes.length, 0);
    assert.equal(agenda.atendimentos.length, 0);
  },
);
