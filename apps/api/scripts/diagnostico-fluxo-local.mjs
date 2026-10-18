import { randomUUID } from 'node:crypto';

const baseUrl = (process.env.CONECTALAR_API_BASE_URL ?? 'http://127.0.0.1:3012')
  .replace(/\/+$/, '');
const adminEmail = process.env.CONECTALAR_ADMIN_EMAIL ?? 'admin.demo@conectalar.local';
const adminSenha = process.env.CONECTALAR_ADMIN_SENHA ?? 'ConectaLarDemo123!';
const senhaTeste = process.env.CONECTALAR_DIAGNOSTICO_SENHA ?? 'ConectaLarTeste123!';

const results = [];

async function main() {
  const suffix = randomUUID().slice(0, 8);
  const ctx = { suffix };

  await step('API /health', async () => {
    const data = await request('GET', 'health');
    assert(data.status === 'ok', 'Health check nao retornou status ok.');
    return `online em ${baseUrl}`;
  });

  await step('Login administrador demo', async () => {
    const data = await request('POST', 'auth/login', undefined, {
      email: adminEmail,
      senha: adminSenha,
    }, 201);
    ctx.adminToken = data.token.accessToken;
    return adminEmail;
  });

  await step('Cadastro de cliente, profissional e terceiro', async () => {
    ctx.cliente = await cadastrar('cliente', `Cliente Diagnostico ${suffix}`, `cliente.${suffix}@conectalar.local`);
    ctx.profissional = await cadastrar('profissional', `Prof Diagnostico ${suffix}`, `profissional.${suffix}@conectalar.local`);
    ctx.terceiro = await cadastrar('cliente', `Cliente Externo ${suffix}`, `externo.${suffix}@conectalar.local`);
    return `cliente=${ctx.cliente.usuario.id}, profissional=${ctx.profissional.usuario.id}`;
  });

  await step('Categorias publicas disponiveis', async () => {
    const data = await request('GET', 'categorias');
    assert(Array.isArray(data.categorias) && data.categorias.length >= 2, 'Seed de categorias insuficiente.');
    ctx.categoriaA = data.categorias[0];
    ctx.categoriaB = data.categorias[1];
    return `${ctx.categoriaA.nome}, ${ctx.categoriaB.nome}`;
  });

  await step('Perfil profissional, ofertas e disponibilidade', async () => {
    const perfilResponse = await request('PUT', 'profissionais/me', ctx.profissional.token, {
      descricao: 'Perfil criado pelo diagnostico profundo para validar o fluxo principal completo.',
      bairro: 'Centro',
      precoInicial: 100,
      servicos: [
        {
          nome: 'Servico diagnostico inicial',
          duracaoMinutos: 120,
          categoriaId: ctx.categoriaA.id,
          precoInicial: 110,
        },
        {
          nome: 'Servico diagnostico escolhido',
          duracaoMinutos: 120,
          categoriaId: ctx.categoriaB.id,
          precoInicial: 140.5,
        },
      ],
    });
    ctx.perfil = perfilResponse.profissional;
    ctx.oferta = ctx.perfil.servicos.find((servico) => servico.nome === 'Servico diagnostico escolhido');
    assert(ctx.oferta, 'Oferta escolhida nao retornou no perfil.');
    await request('PUT', 'profissionais/me/disponibilidade', ctx.profissional.token, {
      disponibilidades: Array.from({ length: 7 }, (_, diaSemana) => ({
        diaSemana,
        horaInicio: '08:00',
        horaFim: '18:00',
      })),
    });
    return `perfil=${ctx.perfil.id}, oferta=${ctx.oferta.id}`;
  });

  await step('Endereco do cliente', async () => {
    const data = await request('POST', 'clientes/me/enderecos', ctx.cliente.token, {
      apelido: 'Casa diagnostico',
      logradouro: 'Rua Privada Diagnostico',
      numero: '123',
      bairro: 'Centro',
      cidade: 'Sao Paulo',
      uf: 'SP',
      principal: true,
    }, 201);
    ctx.endereco = data.endereco;
    return `endereco=${ctx.endereco.id}`;
  });

  await step('Solicitacao criada com endereco protegido', async () => {
    const dataServico = futureDate(9);
    const data = await request('POST', 'solicitacoes', ctx.cliente.token, {
      profissionalId: ctx.perfil.id,
      servicoId: ctx.oferta.id,
      categoriaId: ctx.categoriaA.id,
      enderecoId: ctx.endereco.id,
      descricao: 'Atendimento criado pelo diagnostico profundo para validar solicitacao.',
      bairroAtendimento: 'Centro',
      dataServico,
      horarioServico: '10:30',
    }, 201);
    ctx.solicitacao = data.solicitacao;
    assert(ctx.solicitacao.status === 'aguardando_resposta', 'Solicitacao nao iniciou aguardando resposta.');
    assert(ctx.solicitacao.servicoId === ctx.oferta.id, 'Servico escolhido nao foi preservado.');
    assert(ctx.solicitacao.categoria.id === ctx.categoriaB.id, 'Categoria nao foi derivada da oferta.');
    const vistaProfissional = (await request('GET', `solicitacoes/${ctx.solicitacao.id}`, ctx.profissional.token)).solicitacao;
    assert(vistaProfissional.enderecoCompletoLiberado === false, 'Endereco foi liberado antes do aceite.');
    assert(vistaProfissional.enderecoAtendimento === null, 'Endereco completo apareceu antes do aceite.');
    await request('GET', `solicitacoes/${ctx.solicitacao.id}`, ctx.terceiro.token, undefined, 403);
    return `solicitacao=${ctx.solicitacao.id}`;
  });

  await step('Aceite profissional libera endereco autorizado', async () => {
    const data = await request('PATCH', `solicitacoes/${ctx.solicitacao.id}/aceitar`, ctx.profissional.token);
    ctx.solicitacao = data.solicitacao;
    assert(ctx.solicitacao.status === 'aceita_agendada', 'Solicitacao nao ficou aceita_agendada.');
    assert(ctx.solicitacao.enderecoCompletoLiberado === true, 'Endereco nao foi liberado ao profissional apos aceite.');
    assert(ctx.solicitacao.enderecoAtendimento?.logradouro === 'Rua Privada Diagnostico', 'Endereco completo esperado nao retornou.');
    return 'aceita_agendada';
  });

  await step('Agenda profissional lista atendimento aceito', async () => {
    const mes = ctx.solicitacao.dataServico.slice(0, 7);
    const data = await request('GET', `profissionais/me/agenda?mes=${mes}`, ctx.profissional.token);
    const atendimento = data.atendimentos.find((item) => item.id === ctx.solicitacao.id);
    assert(atendimento, 'Atendimento aceito nao apareceu na agenda.');
    assert(atendimento.enderecoAtendimento?.logradouro === 'Rua Privada Diagnostico', 'Agenda nao liberou endereco completo do atendimento aceito.');
    return `agenda=${mes}`;
  });

  await step('Chat entre cliente e profissional', async () => {
    await request('POST', `solicitacoes/${ctx.solicitacao.id}/mensagens`, ctx.cliente.token, {
      conteudo: 'Mensagem do cliente no diagnostico.',
    }, 201);
    await request('POST', `solicitacoes/${ctx.solicitacao.id}/mensagens`, ctx.profissional.token, {
      conteudo: 'Resposta do profissional no diagnostico.',
    }, 201);
    const data = await request('GET', `solicitacoes/${ctx.solicitacao.id}/mensagens`, ctx.cliente.token);
    assert(data.mensagens.length >= 2, 'Mensagens do chat nao foram listadas.');
    return `${data.mensagens.length} mensagens`;
  });

  await step('Conclusao e avaliacoes', async () => {
    const concluida = await request('PATCH', `solicitacoes/${ctx.solicitacao.id}/concluir`, ctx.cliente.token);
    assert(concluida.solicitacao.status === 'conclusao_confirmada', 'Solicitacao nao foi concluida.');
    const avaliacaoProfissional = await request(
      'POST',
      `solicitacoes/${ctx.solicitacao.id}/avaliacoes/profissional`,
      ctx.cliente.token,
      { nota: 5, comentario: 'Avaliacao criada pelo diagnostico profundo.' },
      201,
    );
    ctx.avaliacaoId = avaliacaoProfissional.avaliacao.id;
    await request(
      'POST',
      `solicitacoes/${ctx.solicitacao.id}/avaliacoes/cliente`,
      ctx.profissional.token,
      { nota: 5, comentario: 'Cliente validado pelo diagnostico profundo.' },
      201,
    );
    return `avaliacao=${ctx.avaliacaoId}`;
  });

  await step('Moderacao de avaliacao e lista publica', async () => {
    await request('PATCH', `avaliacoes/${ctx.avaliacaoId}/moderacao`, ctx.adminToken, {
      moderacaoStatus: 'aprovada',
    });
    const data = await request('GET', `profissionais/${ctx.perfil.id}/avaliacoes`);
    assert(data.resumo.quantidadeAvaliacoes >= 1, 'Avaliacao aprovada nao entrou no resumo publico.');
    assert(data.avaliacoes.some((avaliacao) => avaliacao.id === ctx.avaliacaoId), 'Avaliacao aprovada nao apareceu na lista publica.');
    return 'aprovada';
  });

  await step('Denuncia e moderacao administrativa', async () => {
    const denuncia = await request(
      'POST',
      `solicitacoes/${ctx.solicitacao.id}/denuncias`,
      ctx.cliente.token,
      {
        denunciadoId: ctx.profissional.usuario.id,
        motivo: 'comunicacao',
        descricao: 'Denuncia criada pelo diagnostico profundo para validar moderacao administrativa.',
      },
      201,
    );
    ctx.denunciaId = denuncia.denuncia.id;
    const lista = await request('GET', 'denuncias/moderacao?status=pendente', ctx.adminToken);
    assert(lista.denuncias.some((item) => item.id === ctx.denunciaId), 'Denuncia pendente nao apareceu para moderacao.');
    await request('PATCH', `denuncias/${ctx.denunciaId}/moderacao`, ctx.adminToken, {
      status: 'resolvida',
      decisao: 'Denuncia resolvida pelo diagnostico profundo.',
    });
    return `denuncia=${ctx.denunciaId}`;
  });

  await step('Auditoria administrativa registra moderacoes', async () => {
    const data = await request('GET', 'admin/painel/auditoria', ctx.adminToken);
    const alvoIds = new Set([ctx.avaliacaoId, ctx.denunciaId]);
    const eventos = data.eventos.filter((evento) => alvoIds.has(evento.alvoId));
    assert(eventos.some((evento) => evento.alvoTipo === 'avaliacao'), 'Auditoria de avaliacao nao encontrada.');
    assert(eventos.some((evento) => evento.alvoTipo === 'denuncia'), 'Auditoria de denuncia nao encontrada.');
    return `${eventos.length} eventos relacionados`;
  });

  printSummary();
  if (results.some((item) => item.status === 'fail')) process.exitCode = 1;
}

async function cadastrar(tipo, nome, email) {
  const data = await request('POST', 'auth/cadastro', undefined, {
    nome,
    email,
    senha: senhaTeste,
    tipo,
  }, 201);
  assert(data.devCode, 'O diagnóstico exige EXPOSE_EMAIL_VERIFICATION_CODE=true em ambiente local de teste sem SMTP.');
  await request('POST', 'auth/email/verificacao/confirmar', data.token.accessToken,
    { codigo: data.devCode }, 201);
  return {
    token: data.token.accessToken,
    usuario: data.usuario,
  };
}

async function step(name, action) {
  try {
    const detail = await action();
    results.push({ status: 'pass', name, detail });
    console.log(`[OK] ${name}: ${detail}`);
  } catch (error) {
    results.push({ status: 'fail', name, detail: error.message });
    console.log(`[FALHA] ${name}: ${error.message}`);
  }
}

async function request(method, path, token, body, expectedStatus = 200) {
  const response = await fetch(`${baseUrl}/${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (response.status !== expectedStatus) {
    const message = typeof data.message === 'string' ? data.message : text;
    throw new Error(`${method} /${path}: esperado ${expectedStatus}, recebeu ${response.status} (${message})`);
  }
  return data;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function futureDate(days) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function printSummary() {
  const failures = results.filter((item) => item.status === 'fail').length;
  console.log('\nDiagnostico profundo ConectaLar\n');
  for (const item of results) {
    const marker = item.status === 'pass' ? '[OK]' : '[FALHA]';
    console.log(`${marker} ${item.name}: ${item.detail}`);
  }
  console.log(`\nResultado: ${results.length - failures}/${results.length} verificacoes OK.`);
}

main().catch((error) => {
  console.error('Diagnostico profundo falhou antes de concluir.');
  console.error(error);
  process.exitCode = 1;
});
