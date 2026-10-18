import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

const url = process.env.CONECTALAR_TEST_API_URL;

test('duration, free windows and concurrent overlapping acceptances with MySQL', { skip: !url }, async (t) => {
  assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname));
  async function request(method, path, token, body, expected = 200) {
    const response = await fetch(`${url}/${path}`, {
      method,
      headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const data = await response.json();
    if (expected !== null) assert.equal(response.status, expected, `${method} ${path} returned ${response.status}`);
    return { status: response.status, data };
  }
  async function register(tipo) {
    const { data } = await request('POST', 'auth/cadastro', null, {
      nome: `Homologação ${tipo}`, tipo, senha: 'ConectaLarTeste123!',
      email: `agenda.${randomUUID()}@conectalar.local`,
    }, 201);
    assert.ok(data.devCode, 'Use an isolated local API with EXPOSE_EMAIL_VERIFICATION_CODE=true.');
    await request('POST', 'auth/email/verificacao/confirmar', data.token.accessToken, { codigo: data.devCode }, 201);
    return data.token.accessToken;
  }
  const cliente = await register('cliente');
  const categorias = (await request('GET', 'categorias')).data.categorias;
  const endereco = (await request('POST', 'clientes/me/enderecos', cliente, {
    apelido: 'Teste', logradouro: 'Rua Fictícia', numero: '1', bairro: 'Centro',
    cidade: 'Belo Horizonte', uf: 'MG', principal: true,
  }, 201)).data.endereco;
  const dataServico = `${new Date().getUTCFullYear() + 1}-10-18`;

  for (const tipo of ['profissional', 'empresa']) {
    await t.test(`${tipo}: capacity one, consecutive bookings and immutable request duration`, async () => {
      const token = await register(tipo);
      const payload = {
        descricao: 'Serviço fictício de homologação da agenda.', bairro: 'Centro',
        servicos: [{ nome: 'Serviço de duas horas', categoriaId: categorias[0].id, duracaoMinutos: 120 }],
      };
      const perfil = (await request('PUT', 'profissionais/me', token, payload)).data.profissional;
      const oferta = perfil.servicos[0];
      await request('PUT', 'profissionais/me/disponibilidade', token, {
        disponibilidades: Array.from({ length: 7 }, (_, diaSemana) => ({ diaSemana, horaInicio: '08:00', horaFim: '18:00' })),
      });
      await request('PUT', 'profissionais/me/servicos', token,
        { servicos: [{ nome: 'Sem duração' }] }, 400);
      const criar = async (horarioServico, expected = 201) => (await request('POST', 'solicitacoes', cliente, {
        profissionalId: perfil.id, servicoId: oferta.id, enderecoId: endereco.id,
        descricao: 'Atendimento fictício para testar sobreposição.', bairroAtendimento: 'Centro',
        dataServico, horarioServico, duracaoMinutos: 1,
      }, expected)).data.solicitacao;
      await criar('17:00', 400);
      const a = await criar('10:00');
      const b = await criar('10:30');
      assert.equal(a.duracaoMinutos, 120, 'client-supplied duration cannot shorten a booking');
      await request('PUT', 'profissionais/me/servicos', token, { servicos: [{
        id: oferta.id, nome: oferta.nome, categoriaId: categorias[0].id, duracaoMinutos: 60,
      }] });
      assert.equal((await request('GET', `solicitacoes/${a.id}`, cliente)).data.solicitacao.duracaoMinutos, 120);
      const accepted = await Promise.all([a, b].map((p) => request('PATCH', `solicitacoes/${p.id}/aceitar`, token, undefined, null)));
      assert.deepEqual(accepted.map((r) => r.status).sort(), [200, 409]);
      const winner = accepted.find((r) => r.status === 200).data.solicitacao;
      const fim = winner.horarioServico === '10:00' ? '12:00' : '12:30';
      const adjacent = await criar(fim);
      await request('PATCH', `solicitacoes/${adjacent.id}/aceitar`, token);
      await criar('11:00', 409);
      const livres = (await request('GET', `profissionais/${perfil.id}/horarios?data=${dataServico}&servicoId=${oferta.id}`)).data;
      assert.equal(livres.fusoHorario, 'America/Sao_Paulo');
      assert.equal(livres.duracaoMinutos, 60);
      assert.deepEqual(Object.keys(livres).sort(), ['data', 'duracaoMinutos', 'fusoHorario', 'intervalos']);
      assert.ok(livres.intervalos.every((item) => item.horaFim <= winner.horarioServico || item.horaInicio >= (fim === '12:00' ? '13:00' : '13:30')));
      const agenda = (await request('GET', `profissionais/me/agenda?mes=${dataServico.slice(0, 7)}`, token)).data;
      assert.equal(agenda.atendimentos.length, 2);
      assert.equal(agenda.atendimentos.find((p) => p.id === winner.id).duracaoMinutos, 120);
    });
  }
});
