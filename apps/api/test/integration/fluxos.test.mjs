import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

// Execute somente contra uma API local com banco descartável e migrations aplicadas.
const url = process.env.CONECTALAR_TEST_API_URL;
const adminEmail = process.env.CONECTALAR_TEST_ADMIN_EMAIL;
const adminSenha = process.env.CONECTALAR_TEST_ADMIN_SENHA;

test(
  'ofertas, agenda concorrente, permissões e avaliações com MySQL',
  {
    skip: !url || !adminEmail || !adminSenha,
  },
  async (t) => {
    assert.ok(
      ['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname),
    );
    const suffix = randomUUID().slice(0, 8);
    const senha = 'ConectaLarTeste123!';
    async function request(method, path, token, body, status = 200) {
      const response = await fetch(`${url.replace(/\/$/, '')}/${path}`, {
        method,
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const data = await response.json();
      if (status !== null)
        assert.equal(
          response.status,
          status,
          `${method} ${path}: ${JSON.stringify(data)}`,
        );
      return { status: response.status, data };
    }
    async function cadastro(tipo, sufixo = '') {
      const { data } = await request(
        'POST',
        'auth/cadastro',
        null,
        {
          nome: `Teste ${tipo} ${suffix}${sufixo}`,
          email: `${tipo}${sufixo}.${suffix}@conectalar.local`,
          senha,
          tipo,
        },
        201,
      );
      return { token: data.token.accessToken, usuario: data.usuario };
    }
    const cliente = await cadastro('cliente');
    const profissional = await cadastro('profissional');
    const terceiro = await cadastro('cliente', 'externo');
    const { data: admin } = await request(
      'POST',
      'auth/login',
      null,
      {
        email: adminEmail,
        senha: adminSenha,
      },
      201,
    );
    const adminToken = admin.token.accessToken;
    const categorias = (await request('GET', 'categorias')).data.categorias;
    assert.ok(
      categorias.length >= 2,
      'Aplique o seed de demonstração no banco de teste.',
    );
    const { data: perfilResponse } = await request(
      'PUT',
      'profissionais/me',
      profissional.token,
      {
        descricao:
          'Serviços residenciais para testes automatizados de integração.',
        bairro: 'Centro',
        precoInicial: 50,
        servicos: [
          {
            nome: 'Primeira oferta',
            categoriaId: categorias[0].id,
            precoInicial: 60,
          },
          {
            nome: 'Oferta escolhida',
            categoriaId: categorias[1].id,
            precoInicial: 125.5,
          },
        ],
      },
    );
    const perfil = perfilResponse.profissional;
    let ofertas = perfil.servicos;
    const escolhida = ofertas[1];
    await request(
      'PUT',
      'profissionais/me/disponibilidade',
      profissional.token,
      {
        disponibilidades: Array.from({ length: 7 }, (_, diaSemana) => ({
          diaSemana,
          horaInicio: '08:00',
          horaFim: '18:00',
        })),
      },
    );
    const { data: enderecoResponse } = await request(
      'POST',
      'clientes/me/enderecos',
      cliente.token,
      {
        apelido: 'Casa de teste',
        logradouro: 'Rua Privada de Teste',
        numero: '12',
        bairro: 'Centro',
        cidade: 'São Paulo',
        uf: 'SP',
        principal: true,
      },
      201,
    );
    const endereco = enderecoResponse.endereco;
    const dataServico = `${new Date().getUTCFullYear() + 1}-10-15`;
    async function criar(horarioServico = '10:00') {
      return (
        await request(
          'POST',
          'solicitacoes',
          cliente.token,
          {
            profissionalId: perfil.id,
            servicoId: escolhida.id,
            // A API deve derivar a categoria da oferta e ignorar esta divergência.
            categoriaId: categorias[0].id,
            enderecoId: endereco.id,
            descricao: 'Atendimento para validar o fluxo de solicitação.',
            bairroAtendimento: 'Centro',
            dataServico,
            horarioServico,
          },
          201,
        )
      ).data.solicitacao;
    }
    const pedido = await criar();
    await t.test(
      'a solicitação preserva oferta, categoria, preço e endereço protegido',
      async () => {
        assert.equal(pedido.servicoId, escolhida.id);
        assert.equal(pedido.nomeServico, escolhida.nome);
        assert.equal(pedido.categoria.id, categorias[1].id);
        assert.equal(pedido.precoInicial, 125.5);
        assert.equal(pedido.status, 'aguardando_resposta');
        assert.equal(pedido.dataServico, dataServico);
        const privado = (
          await request('GET', `solicitacoes/${pedido.id}`, profissional.token)
        ).data.solicitacao;
        assert.equal(privado.enderecoAtendimento, null);
        assert.equal(privado.enderecoCompletoLiberado, false);
        await request(
          'GET',
          `solicitacoes/${pedido.id}`,
          terceiro.token,
          undefined,
          403,
        );
        await request(
          'PATCH',
          `solicitacoes/${pedido.id}/aceitar`,
          cliente.token,
          undefined,
          403,
        );
      },
    );
    await t.test(
      'editar e desativar ofertas preserva IDs e o nome original do pedido',
      async () => {
        ofertas = (
          await request(
            'PUT',
            'profissionais/me/servicos',
            profissional.token,
            {
              servicos: ofertas.map((o) => ({
                id: o.id,
                nome: `${o.nome} editada`,
                categoriaId: o.categoriaId,
                precoInicial: o.precoInicial,
              })),
            },
          )
        ).data.servicos;
        assert.ok(
          ofertas.some(
            (o) =>
              o.id === escolhida.id && o.nome === `${escolhida.nome} editada`,
          ),
        );
        assert.equal(
          (await request('GET', `solicitacoes/${pedido.id}`, cliente.token))
            .data.solicitacao.nomeServico,
          escolhida.nome,
        );
        const ativo = ofertas.find((o) => o.id === escolhida.id);
        const desativada = ofertas.find((o) => o.id !== escolhida.id);
        await request('PUT', 'profissionais/me/servicos', profissional.token, {
          servicos: [ativo],
        });
        const atuais = (
          await request('GET', 'profissionais/me/servicos', profissional.token)
        ).data.servicos;
        assert.equal(atuais.length, 1);
        assert.equal(atuais[0].id, escolhida.id);
        await request(
          'POST',
          'solicitacoes',
          cliente.token,
          {
            profissionalId: perfil.id,
            servicoId: desativada.id,
            descricao: 'Oferta desativada não pode ser solicitada.',
            bairroAtendimento: 'Centro',
            dataServico,
            horarioServico: '11:00',
          },
          400,
        );
      },
    );
    const concorrente = await criar();
    await t.test(
      'dois aceites simultâneos no mesmo horário confirmam somente um pedido',
      async () => {
        const respostas = await Promise.all(
          [pedido, concorrente].map((p) =>
            request(
              'PATCH',
              `solicitacoes/${p.id}/aceitar`,
              profissional.token,
              undefined,
              null,
            ),
          ),
        );
        assert.deepEqual(respostas.map((r) => r.status).sort(), [200, 409]);
        assert.match(
          respostas.find((r) => r.status === 409).data.message,
          /horário/,
        );
        const estados = await Promise.all(
          [pedido, concorrente].map(
            async (p) =>
              (await request('GET', `solicitacoes/${p.id}`, cliente.token)).data
                .solicitacao.status,
          ),
        );
        assert.equal(estados.filter((s) => s === 'aceita_agendada').length, 1);
      },
    );
    const agenda = (
      await request(
        'GET',
        `profissionais/me/agenda?mes=${dataServico.slice(0, 7)}`,
        profissional.token,
      )
    ).data;
    const aceitoId = agenda.atendimentos.find((p) =>
      [pedido.id, concorrente.id].includes(p.id),
    ).id;
    await t.test(
      'a agenda libera o endereço somente do atendimento aceito',
      async () => {
        const atendimento = agenda.atendimentos.find((p) => p.id === aceitoId);
        assert.equal(atendimento.enderecoCompletoLiberado, true);
        assert.equal(
          atendimento.enderecoAtendimento.logradouro,
          'Rua Privada de Teste',
        );
        assert.deepEqual(
          atendimento.enderecoAtendimento,
          atendimento.enderecoCompleto,
        );
        const outroId = aceitoId === pedido.id ? concorrente.id : pedido.id;
        assert.equal(
          (await request('GET', `solicitacoes/${outroId}`, profissional.token))
            .data.solicitacao.enderecoAtendimento,
          null,
        );
      },
    );
    await t.test(
      'aceitar e recusar simultaneamente não sobrescrevem um estado final',
      async () => {
        const novo = await criar('11:00');
        const respostas = await Promise.all(
          ['aceitar', 'recusar'].map((acao) =>
            request(
              'PATCH',
              `solicitacoes/${novo.id}/${acao}`,
              profissional.token,
              undefined,
              null,
            ),
          ),
        );
        assert.deepEqual(respostas.map((r) => r.status).sort(), [200, 409]);
        const estado = (
          await request('GET', `solicitacoes/${novo.id}`, cliente.token)
        ).data.solicitacao.status;
        assert.equal(
          estado,
          respostas.find((r) => r.status === 200).data.solicitacao.status,
        );
      },
    );
    await t.test(
      'o aceite revalida a disponibilidade atual e cancelamento libera o horário',
      async () => {
        const novo = await criar('12:00');
        await request(
          'PUT',
          'profissionais/me/disponibilidade',
          profissional.token,
          { disponibilidades: [] },
        );
        await request(
          'PATCH',
          `solicitacoes/${novo.id}/aceitar`,
          profissional.token,
          undefined,
          409,
        );
        await request(
          'PUT',
          'profissionais/me/disponibilidade',
          profissional.token,
          {
            disponibilidades: Array.from({ length: 7 }, (_, diaSemana) => ({
              diaSemana,
              horaInicio: '08:00',
              horaFim: '18:00',
            })),
          },
        );
        await request(
          'PATCH',
          `solicitacoes/${novo.id}/aceitar`,
          profissional.token,
        );
        await request(
          'PATCH',
          `solicitacoes/${novo.id}/cancelar`,
          cliente.token,
        );
        const substituto = await criar('12:00');
        await request(
          'PATCH',
          `solicitacoes/${substituto.id}/aceitar`,
          profissional.token,
        );
      },
    );
    await t.test(
      'duas atualizações simultâneas de disponibilidade não misturam intervalos',
      async () => {
        const intervalos = ['08:00', '09:00'].map((horaInicio) =>
          Array.from({ length: 7 }, (_, diaSemana) => ({
            diaSemana,
            horaInicio,
            horaFim: '18:00',
          })),
        );
        await Promise.all(
          intervalos.map((disponibilidades) =>
            request(
              'PUT',
              'profissionais/me/disponibilidade',
              profissional.token,
              { disponibilidades },
            ),
          ),
        );
        const atual = (
          await request(
            'GET',
            'profissionais/me/disponibilidade',
            profissional.token,
          )
        ).data.disponibilidades;
        assert.equal(atual.length, 7);
        assert.equal(new Set(atual.map((d) => d.horaInicio)).size, 1);
        assert.equal(new Set(atual.map((d) => d.diaSemana)).size, 7);
      },
    );
    let avaliacaoId;
    await t.test(
      'cada participante avalia uma vez e o estado já enviado é individual',
      async () => {
        await request(
          'POST',
          `solicitacoes/${aceitoId}/avaliacoes/profissional`,
          cliente.token,
          { nota: 5 },
          400,
        );
        await request(
          'PATCH',
          `solicitacoes/${aceitoId}/concluir`,
          cliente.token,
        );
        const { data } = await request(
          'POST',
          `solicitacoes/${aceitoId}/avaliacoes/profissional`,
          cliente.token,
          { nota: 4, comentario: 'Ótimo atendimento de teste.' },
          201,
        );
        avaliacaoId = data.avaliacao.id;
        assert.equal(
          (await request('GET', `solicitacoes/${aceitoId}`, cliente.token)).data
            .solicitacao.avaliado,
          true,
        );
        assert.equal(
          (await request('GET', `solicitacoes/${aceitoId}`, profissional.token))
            .data.solicitacao.avaliado,
          false,
        );
        await request(
          'POST',
          `solicitacoes/${aceitoId}/avaliacoes/profissional`,
          cliente.token,
          { nota: 5 },
          409,
        );
        await request(
          'POST',
          `solicitacoes/${aceitoId}/avaliacoes/cliente`,
          profissional.token,
          { nota: 5 },
          201,
        );
        assert.equal(
          (await request('GET', `solicitacoes/${aceitoId}`, profissional.token))
            .data.solicitacao.avaliado,
          true,
        );
        const minhas = (
          await request('GET', 'solicitacoes/me', profissional.token)
        ).data.solicitacoes;
        assert.equal(minhas.find((p) => p.id === aceitoId).avaliado, true);
      },
    );
    await t.test(
      'somente avaliações aprovadas entram na lista pública e na média',
      async () => {
        const path = `profissionais/${perfil.id}/avaliacoes`;
        assert.equal((await request('GET', path)).data.avaliacoes.length, 0);
        await request(
          'PATCH',
          `avaliacoes/${avaliacaoId}/moderacao`,
          adminToken,
          { moderacaoStatus: 'aprovada' },
        );
        const publicas = (await request('GET', path)).data;
        assert.equal(publicas.avaliacoes.length, 1);
        assert.equal(publicas.resumo.quantidadeAvaliacoes, 1);
        assert.equal(publicas.resumo.notaMedia, 4);
        assert.deepEqual(Object.keys(publicas.avaliacoes[0]).sort(), [
          'comentario',
          'criadoEm',
          'id',
          'nota',
        ]);
        const detalhe = (await request('GET', `profissionais/${perfil.id}`))
          .data.profissional;
        assert.equal(detalhe.notaMedia, 4);
        assert.equal(detalhe.quantidadeAvaliacoes, 1);
        assert.deepEqual(
          (
            await request(
              'GET',
              'profissionais/me/avaliacoes',
              profissional.token,
            )
          ).data.resumo,
          publicas.resumo,
        );
        await request(
          'GET',
          'profissionais/me/avaliacoes',
          cliente.token,
          undefined,
          403,
        );
        await request(
          'PATCH',
          `avaliacoes/${avaliacaoId}/moderacao`,
          adminToken,
          { moderacaoStatus: 'rejeitada' },
        );
        const removidas = (await request('GET', path)).data;
        assert.equal(removidas.avaliacoes.length, 0);
        assert.equal(removidas.resumo.notaMedia, null);
        assert.equal(removidas.resumo.quantidadeAvaliacoes, 0);
      },
    );
    await t.test('logout invalida o token utilizado', async () => {
      await request('POST', 'auth/logout', terceiro.token, undefined, 201);
      await request('GET', 'solicitacoes/me', terceiro.token, undefined, 401);
    });
  },
);
