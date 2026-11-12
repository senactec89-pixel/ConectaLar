import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import test from 'node:test';
import mysql from 'mysql2/promise';

const enabled = process.env.CONECTALAR_MYSQL_TEST === '1';

test('MySQL real: migration e administracao do catalogo', { skip: !enabled }, async () => {
  const host = process.env.CONECTALAR_TEST_DB_HOST;
  assert.ok(['127.0.0.1', 'localhost', '::1'].includes(host), 'O banco de teste deve estar em loopback.');
  const port = Number(process.env.CONECTALAR_TEST_DB_PORT ?? '3307');
  assert.ok(Number.isInteger(port) && port > 0 && port <= 65535);
  const user = process.env.CONECTALAR_TEST_DB_USER;
  assert.ok(user, 'Defina CONECTALAR_TEST_DB_USER.');
  const password = process.env.CONECTALAR_TEST_DB_PASSWORD ?? '';
  const database = `conectalar_it_${randomBytes(8).toString('hex')}`;
  const connection = await mysql.createConnection({ host, port, user, password, connectTimeout: 3000 });
  let dataSource;
  let app;
  let created = false;
  try {
    await connection.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    created = true;
    Object.assign(process.env, {
      NODE_ENV: 'test', HOST: '127.0.0.1', PORT: '3000', DB_HOST: host,
      DB_PORT: String(port), DB_USER: user, DB_PASSWORD: password, DB_NAME: database,
      AUTH_TOKEN_SECRET: randomBytes(48).toString('base64url'),
      MFA_SECRET_ENCRYPTION_KEY: randomBytes(32).toString('hex'),
      SMTP_HOST: '', RATE_LIMIT_MAX: '1000',
    });
    const module = await import('../../dist/database/data-source.js');
    dataSource = module.default.default ?? module.default;
    await dataSource.initialize();
    await dataSource.runMigrations();
    assert.equal(Number((await dataSource.query('SELECT COUNT(*) AS total FROM servicos_catalogo'))[0].total), 0);
    await dataSource.undoLastMigration();
    await dataSource.undoLastMigration();
    await dataSource.undoLastMigration();
    await dataSource.undoLastMigration();
    assert.equal(Number((await dataSource.query("SELECT COUNT(*) AS total FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'servicos_catalogo'"))[0].total), 0);
    await dataSource.runMigrations();

    const { createApp } = await import('../../dist/app.factory.js');
    const { TokenService } = await import('../../dist/auth/token.service.js');
    const { termoAtual } = await import('../../dist/termos/termos.service.js');
    const { bloquearOfertaCatalogo } = await import('../../dist/solicitacoes/oferta-catalogo.js');
    app = await createApp();
    await app.listen(0, '127.0.0.1');
    const url = `http://127.0.0.1:${app.getHttpServer().address().port}`;
    await dataSource.query(`INSERT INTO usuarios (nome,email,email_verificado,tipo,senha_hash,ativo,mfa_ativo)
      VALUES ('Admin Teste','admin.catalogo@example.invalid',1,'administrador','teste',1,1),
             ('Cliente Teste','cliente.catalogo@example.invalid',1,'cliente','teste',1,0),
             ('Profissional Teste','profissional.catalogo@example.invalid',1,'profissional','teste',1,0)`);
    const users = await dataSource.query("SELECT id, tipo FROM usuarios WHERE email IN ('admin.catalogo@example.invalid', 'cliente.catalogo@example.invalid', 'profissional.catalogo@example.invalid')");
    const admin = users.find((item) => item.tipo === 'administrador');
    const client = users.find((item) => item.tipo === 'cliente');
    const professional = users.find((item) => item.tipo === 'profissional');
    for (const account of users) {
      await dataSource.query("INSERT INTO termo_aceites (usuario_id,versao,canal,aceito_em) VALUES (?,?,'integracao',CURRENT_TIMESTAMP(6))", [account.id, termoAtual.versao]);
    }
    const tokens = new TokenService();
    const adminToken = tokens.createAccessToken({ id: admin.id, tipo: admin.tipo, tokenVersion: 0 }).accessToken;
    const clientToken = tokens.createAccessToken({ id: client.id, tipo: client.tipo, tokenVersion: 0 }).accessToken;
    const professionalToken = tokens.createAccessToken({ id: professional.id, tipo: professional.tipo, tokenVersion: 0 }).accessToken;
    async function request(method, path, token, body, expected) {
      const response = await fetch(`${url}${path}`, {
        method, headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const data = await response.json();
      assert.equal(response.status, expected, `${method} ${path}: ${JSON.stringify(data)}`);
      return data;
    }
    const categories = (await request('GET', '/categorias', null, null, 200)).categorias;
    const category = categories.find((item) => item.nome === 'Manutencao');
    assert.ok(category);
    const base = `/admin/catalogo/categorias/${category.id}/servicos`;
    await request('GET', base, null, null, 401);
    await request('GET', base, clientToken, null, 403);
    await request('POST', base, clientToken, { nome: 'Cadeira' }, 403);
    const item = (await request('POST', base, adminToken, { nome: 'Montagem de cadeira', descricao: 'Seguir manual' }, 201)).servico;
    assert.equal(item.ativo, false);
    await request('POST', base, adminToken, { nome: 'montagem de cadeira' }, 400);
    assert.equal((await request('GET', `${base}?ativo=false&termo=cadeira`, adminToken, null, 200)).servicos[0].id, item.id);
    assert.equal((await request('PATCH', `${base}/${item.id}`, adminToken, { ativo: true, nome: 'Montagem de cadeira simples' }, 200)).servico.ativo, true);
    await request('PATCH', `/admin/catalogo/categorias/${categories.find((c) => c.id !== category.id).id}/servicos/${item.id}`, adminToken, { ativo: false }, 404);
    assert.equal((await request('GET', `/categorias/${category.id}/servicos`, null, null, 200)).servicos[0].id, item.id);
    const profile = (await request('PUT', '/profissionais/me', professionalToken,
      { descricao: 'Perfil profissional ficticio para os testes.', bairro: 'Centro', cidade: 'Belo Horizonte', uf: 'MG', servicos: [] }, 200)).profissional;
    const saveOffers = (servicos, expected) => request('PUT', '/profissionais/me/servicos', professionalToken, { servicos }, expected);
    await saveOffers([{ nome: 'Nome livre novo' }], 400);
    await saveOffers([{ servicoCatalogoId: item.id, categoriaId: categories.find((c) => c.id !== category.id).id }], 400);
    const offer = (await saveOffers([{ servicoCatalogoId: item.id, nome: 'Nome ignorado', precoInicial: 120, duracaoMinutos: 90 }], 200)).servicos[0];
    assert.equal(offer.nome, 'Montagem de cadeira simples');
    assert.equal(offer.servicoCatalogoId, item.id);
    assert.equal(offer.categoriaId, category.id);
    assert.equal((await dataSource.transaction((manager) => bloquearOfertaCatalogo(manager, profile.id, offer.id))).id, offer.id);
    await assert.rejects(dataSource.transaction((manager) => bloquearOfertaCatalogo(manager, profile.id + 10000, offer.id)));
    await assert.rejects(dataSource.transaction((manager) => bloquearOfertaCatalogo(manager, profile.id, offer.id + 10000)));
    await request('PUT', '/profissionais/me/servicos', professionalToken, {}, 400);
    assert.equal((await request('GET', '/profissionais/me/servicos', professionalToken, null, 200)).servicos[0].ativo, true);
    assert.equal((await request('GET', `/profissionais/${profile.id}`, null, null, 200)).profissional.servicos.some((s) => s.id === offer.id), true);
    const search = await request('GET', `/profissionais?servicoCatalogoId=${item.id}`, null, null, 200);
    assert.deepEqual(search.profissionais.map((p) => p.id), [profile.id]);
    assert.deepEqual(search.profissionais[0].servicos.map((s) => s.servicoCatalogoId), [item.id]);
    assert.equal(search.profissionais[0].podeReceberSolicitacoes, false);
    await dataSource.query('UPDATE profissionais SET latitude=?,longitude=? WHERE id=?', ['-19.9200000', '-43.9400000', profile.id]);
    const nearby = await request('POST', '/profissionais/busca', null,
      { latitude: -19.92, longitude: -43.94, raioKm: 5, servicoCatalogoId: item.id }, 201);
    assert.deepEqual(nearby.profissionais.map((p) => p.id), [profile.id]);
    assert.equal((await request('GET', `/profissionais?servicoCatalogoId=${item.id}&categoriaId=${categories.find((c) => c.id !== category.id).id}`, null, null, 200)).profissionais.length, 0);
    await request('GET', '/profissionais?servicoCatalogoId=0', null, null, 400);
    await saveOffers([{ servicoCatalogoId: item.id }, { servicoCatalogoId: item.id }], 400);
    assert.equal((await saveOffers([{ servicoCatalogoId: item.id, precoInicial: 140 }], 200)).servicos[0].id, offer.id);
    await dataSource.query("INSERT INTO profissional_servicos (profissional_id,categoria_id,nome,ativo) VALUES (?,?,'Oferta legada',1)", [profile.id, category.id]);
    const legacy = (await request('GET', '/profissionais/me/servicos', professionalToken, null, 200)).servicos.find((s) => s.servicoCatalogoId === null);
    assert.ok(legacy);
    await saveOffers([{ id: legacy.id, nome: 'Oferta legada', categoriaId: category.id }, { id: offer.id, servicoCatalogoId: item.id }], 200);
    await request('PUT', '/profissionais/me', professionalToken,
      { descricao: 'Perfil atualizado sem alterar servicos.', bairro: 'Centro', cidade: 'Belo Horizonte', uf: 'MG' }, 200);
    assert.equal((await request('GET', '/profissionais/me/servicos', professionalToken, null, 200)).servicos.filter((s) => s.ativo).length, 2);
    await saveOffers([{ id: legacy.id, servicoCatalogoId: item.id }], 400);
    await request('PATCH', `/categorias/${category.id}`, adminToken, { ativo: false }, 200);
    await assert.rejects(dataSource.transaction((manager) => bloquearOfertaCatalogo(manager, profile.id, offer.id)));
    await request('GET', `/categorias/${category.id}/servicos`, null, null, 404);
    assert.equal((await request('GET', '/profissionais/me/servicos', professionalToken, null, 200)).servicos.find((s) => s.id === offer.id).disponivelNoCatalogo, false);
    await saveOffers([{ id: offer.id, servicoCatalogoId: item.id, ativo: true }], 200);
    await request('PATCH', `/categorias/${category.id}`, adminToken, { ativo: true }, 200);
    await request('PATCH', `${base}/${item.id}`, adminToken, { ativo: false }, 200);
    await assert.rejects(dataSource.transaction((manager) => bloquearOfertaCatalogo(manager, profile.id, offer.id)));
    const offers = (await request('GET', '/profissionais/me/servicos', professionalToken, null, 200)).servicos;
    assert.equal(offers.find((s) => s.id === offer.id).disponivelNoCatalogo, false);
    assert.equal((await request('GET', `/profissionais/${profile.id}`, null, null, 200)).profissional.servicos.some((s) => s.id === offer.id), false);
    assert.equal((await request('GET', `/profissionais?servicoCatalogoId=${item.id}`, null, null, 200)).profissionais.length, 0);
    assert.equal((await request('GET', `/categorias/${category.id}/servicos`, null, null, 200)).servicos.length, 0);
    await saveOffers([{ id: offer.id, servicoCatalogoId: item.id, ativo: true }], 200);
    await saveOffers([{ servicoCatalogoId: item.id, ativo: false }], 200);
    await saveOffers([{ id: offer.id, servicoCatalogoId: item.id, ativo: true }], 400);
    const audits = await dataSource.query("SELECT acao, detalhe FROM admin_auditoria WHERE alvo_tipo = 'servico_catalogo' AND alvo_id = ? ORDER BY id", [item.id]);
    assert.deepEqual(audits.map((row) => row.acao), ['servico_catalogo_criado', 'servico_catalogo_atualizado', 'servico_catalogo_atualizado']);
    assert.equal(JSON.parse(audits[1].detalhe).antes.nome, 'Montagem de cadeira');
    const opcoesBase = `${base}/${item.id}/opcoes`;
    await request('GET', opcoesBase, null, null, 401);
    await request('POST', opcoesBase, clientToken, { nome: 'Opcao ficticia' }, 403);
    const opcao = (await request('POST', opcoesBase, adminToken, { nome: 'Opcao ficticia' }, 201)).opcao;
    assert.equal(opcao.ativo, false);
    await request('POST', opcoesBase, adminToken, { nome: 'opcao ficticia' }, 400);
    await request('POST', opcoesBase, adminToken, { nome: 'Outra', ativo: true }, 400);
    await request('PATCH', `${opcoesBase}/${opcao.id}`, adminToken, { ativo: true }, 400);
    await request('PATCH', `${base}/${item.id}`, adminToken, { ativo: true }, 200);
    assert.equal((await request('GET', `/categorias/${category.id}/servicos/${item.id}/opcoes`, null, null, 200)).opcoes.length, 0);
    await request('PATCH', `${opcoesBase}/${opcao.id}`, adminToken, { ativo: true }, 200);
    assert.deepEqual((await request('GET', `/categorias/${category.id}/servicos/${item.id}/opcoes`, null, null, 200)).opcoes.map((o) => o.id), [opcao.id]);
    assert.equal((await request('GET', `${opcoesBase}?ativo=true`, adminToken, null, 200)).opcoes[0].nome, 'Opcao ficticia');
    await request('PATCH', `${opcoesBase}/${opcao.id + 10000}`, adminToken, { nome: 'Nao existe' }, 404);
    const auditOpcao = await dataSource.query("SELECT detalhe FROM admin_auditoria WHERE alvo_tipo='servico_catalogo' AND alvo_id=? ORDER BY id DESC LIMIT 1", [item.id]);
    assert.equal(JSON.parse(auditOpcao[0].detalhe).operacao, 'opcao_atualizada');
    const snapshot = { categoriaId: category.id, nomeCategoria: category.nome, servicoCatalogoId: item.id,
      nomeServico: 'Montagem de cadeira simples', descricao: 'Seguir manual', inclusoes: null, exclusoes: null };
    await dataSource.query(`INSERT INTO solicitacoes
      (cliente_id,profissional_id,categoria_id,servico_id,nome_servico,servico_snapshot,descricao,bairro_atendimento,data_servico,horario_servico,status)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)`, [client.id, profile.id, category.id, offer.id, snapshot.nomeServico,
      JSON.stringify(snapshot), 'Pedido ficticio de teste', 'Centro', '2027-01-15', '10:00', 'aguardando_resposta']);
    const historicalId = (await dataSource.query('SELECT id FROM solicitacoes ORDER BY id DESC LIMIT 1'))[0].id;
    await saveOffers([{ id: offer.id, servicoCatalogoId: item.id, ativo: true }], 200);
    await dataSource.query('INSERT INTO solicitacao_opcoes (solicitacao_id,opcao_id,nome_snapshot) VALUES (?,?,?)', [historicalId, opcao.id, opcao.nome]);
    await request('GET', `/solicitacoes/${historicalId}/opcoes`, professionalToken, null, 200);
    await request('POST', `/solicitacoes/${historicalId}/negociacao`, professionalToken, null, 409);
    await request('PATCH', `/solicitacoes/${historicalId}/aceitar`, professionalToken, null, 409);
    await request('POST', `/solicitacoes/${historicalId}/mensagens`, clientToken, { conteudo: 'Teste ficticio' }, 400);
    await dataSource.query(`INSERT INTO solicitacao_eventos (solicitacao_id,ator_id,tipo,status_anterior,status_novo)
      VALUES (?,?,'negociacao_iniciada','aguardando_resposta','aguardando_resposta')`, [historicalId, professional.id]);
    await dataSource.query("UPDATE solicitacao_eventos SET criado_em=DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 1 DAY) WHERE solicitacao_id=? AND tipo='negociacao_iniciada'", [historicalId]);
    for (let i = 0; i < 101; i++) {
      await dataSource.query("INSERT INTO solicitacao_eventos (solicitacao_id,ator_id,tipo,status_anterior,status_novo) VALUES (?,?,'teste_ficticio','aguardando_resposta','aguardando_resposta')", [historicalId, professional.id]);
    }
    const estadoNegociacao = (await request('GET', `/solicitacoes/${historicalId}`, clientToken, null, 200)).solicitacao;
    assert.equal(estadoNegociacao.eventos.some((evento) => evento.tipo === 'negociacao_iniciada'), false);
    assert.equal(estadoNegociacao.negociacaoIniciada, true);
    const negociacaoRepetida = await request('POST', `/solicitacoes/${historicalId}/negociacao`, professionalToken, null, 200);
    assert.equal(negociacaoRepetida.negociacaoIniciada, true);
    const pedidosProfissional = await request('GET', '/solicitacoes/me', professionalToken, null, 200);
    assert.equal(pedidosProfissional.solicitacoes.find((item) => item.id === historicalId).negociacaoIniciada, true);
    await request('PATCH', `/solicitacoes/${historicalId}/recusar`, professionalToken, null, 409);
    await request('POST', `/solicitacoes/${historicalId}/mensagens`, clientToken, { conteudo: 'Teste ficticio' }, 201);
    const propostas = `/solicitacoes/${historicalId}/propostas-atendimento`;
    const propostaInput = { opcoesIds: [opcao.id], valor: 120, dataServico: '2099-01-15', horarioServico: '10:00', duracaoMinutos: 120 };
    await dataSource.query("INSERT INTO usuarios (nome,email,email_verificado,tipo,senha_hash,ativo,mfa_ativo) VALUES ('Outro Cliente','outro.proposta@example.invalid',1,'cliente','teste',1,0)");
    const outro = (await dataSource.query("SELECT id FROM usuarios WHERE email='outro.proposta@example.invalid'"))[0];
    const outroToken = tokens.createAccessToken({ id: outro.id, tipo: 'cliente', tokenVersion: 0 }).accessToken;
    await dataSource.query("INSERT INTO termo_aceites (usuario_id,versao,canal,aceito_em) VALUES (?,?,'integracao',CURRENT_TIMESTAMP(6))", [outro.id, termoAtual.versao]);
    await request('GET', propostas, outroToken, null, 403);
    await request('GET', `/solicitacoes/${historicalId}/opcoes`, outroToken, null, 403);
    await request('POST', '/solicitacoes', clientToken, { profissionalId: profile.id, servicoId: offer.id, categoriaId: category.id,
      descricao: 'Pedido ficticio de teste', bairroAtendimento: 'Centro', dataServico: '2099-01-15', horarioServico: '10:00', opcoesIds: [opcao.id] }, 409);
    await request('POST', propostas, clientToken, propostaInput, 403);
    await request('POST', propostas, professionalToken, { ...propostaInput, opcoesIds: [] }, 400);
    await request('POST', propostas, professionalToken, { ...propostaInput, opcoesIds: [opcao.id, opcao.id] }, 400);
    await request('POST', propostas, professionalToken, { ...propostaInput, opcoesIds: [opcao.id + 10000] }, 400);
    const outroServico = (await request('POST', base, adminToken, { nome: 'Outro servico ficticio' }, 201)).servico;
    const outraBase = `${base}/${outroServico.id}/opcoes`;
    const outraOpcao = (await request('POST', outraBase, adminToken, { nome: 'Opcao de outro servico' }, 201)).opcao;
    await request('PATCH', `${base}/${outroServico.id}`, adminToken, { ativo: true }, 200);
    await request('PATCH', `${outraBase}/${outraOpcao.id}`, adminToken, { ativo: true }, 200);
    await request('POST', propostas, professionalToken, { ...propostaInput, opcoesIds: [outraOpcao.id] }, 400);
    const proposta1 = (await request('POST', propostas, professionalToken, propostaInput, 201)).propostaId;
    await request('PATCH', `${propostas}/${proposta1}/responder`, professionalToken, { aceitar: false }, 403);
    const proposta2 = (await request('POST', propostas, professionalToken, { ...propostaInput, valor: 130 }, 201)).propostaId;
    await request('PATCH', `${propostas}/${proposta1}/responder`, clientToken, { aceitar: true }, 409);
    await request('PATCH', `${propostas}/${proposta2}/responder`, clientToken, { aceitar: true }, 409);
    const resumo = (await request('GET', propostas, clientToken, null, 200)).propostas;
    assert.deepEqual(resumo.map((p) => [p.versao, p.status, p.valor]), [[2, 'pendente', 130], [1, 'substituida', 120]]);
    assert.deepEqual(resumo[0].opcoes, [{ id: opcao.id, nome: opcao.nome }]);
    await request('PATCH', `${propostas}/${proposta2}/responder`, clientToken, { aceitar: false }, 200);
    await request('PATCH', `${propostas}/${proposta2}/responder`, clientToken, { aceitar: false }, 409);
    const resultados = await Promise.all([
      request('POST', propostas, professionalToken, { ...propostaInput, valor: 140 }, 201),
      request('POST', propostas, professionalToken, { ...propostaInput, valor: 150 }, 201),
    ]);
    assert.notEqual(resultados[0].propostaId, resultados[1].propostaId);
    const concorrentes = (await request('GET', propostas, clientToken, null, 200)).propostas;
    assert.deepEqual(concorrentes.map((p) => p.versao), [4, 3, 2, 1]);
    assert.equal(concorrentes.filter((p) => p.status === 'pendente').length, 1);
    await dataSource.query("UPDATE profissionais SET habilitacao_estado='teste_local_aprovado' WHERE id=?", [profile.id]);
    await dataSource.query("INSERT INTO profissional_disponibilidades (profissional_id,dia_semana,hora_inicio,hora_fim,ativo) VALUES (?,4,'09:00','17:00',1)", [profile.id]);
    process.env.HABILITACAO_MANUAL_LOCAL = 'true';
    const propostaFinal = concorrentes.find((p) => p.status === 'pendente');
    const confirmada = await request('PATCH', `${propostas}/${propostaFinal.id}/responder`, clientToken, { aceitar: true }, 200);
    assert.equal(confirmada.status, 'aceita');
    assert.equal(confirmada.solicitacao.status, 'aceita_agendada');
    const statusFinal = (await dataSource.query("SELECT status,preco_final,DATE_FORMAT(data_servico,'%Y-%m-%d') data_servico,horario_servico FROM solicitacoes WHERE id=?", [historicalId]))[0];
    assert.deepEqual([statusFinal.status, Number(statusFinal.preco_final), statusFinal.data_servico, statusFinal.horario_servico], ['aceita_agendada', Number(propostaFinal.valor), '2099-01-15', '10:00']);
    const eventoConfirmacao = await dataSource.query("SELECT tipo FROM solicitacao_eventos WHERE solicitacao_id=? AND tipo='proposta_atendimento_aceita'", [historicalId]);
    assert.equal(eventoConfirmacao.length, 1);
    await request('PATCH', `${propostas}/${propostaFinal.id}/responder`, clientToken, { aceitar: true }, 409);
    delete process.env.HABILITACAO_MANUAL_LOCAL;
    assert.equal((await request('GET', propostas, professionalToken, null, 200)).propostas.every((item) => item.status !== 'pendente'), true);
    await dataSource.query('UPDATE categorias SET nome=? WHERE id=?', ['Manutencao alterada', category.id]);
    await dataSource.query('UPDATE servicos_catalogo SET nome=?,descricao=? WHERE id=?', ['Novo nome', 'Novo escopo', item.id]);
    const historical = (await request('GET', `/solicitacoes/${historicalId}`, clientToken, null, 200)).solicitacao;
    assert.equal(historical.categoria.nome, category.nome);
    assert.equal(historical.nomeServico, snapshot.nomeServico);
    assert.deepEqual(historical.servicoSnapshot, snapshot);
    const { SnapshotServicoSolicitacao1760140000000 } = await import('../../dist/database/migrations/1760140000000-SnapshotServicoSolicitacao.js');
    const runner = dataSource.createQueryRunner();
    try {
      await assert.rejects(new SnapshotServicoSolicitacao1760140000000().down(runner), /Rollback blocked/);
    } finally {
      await runner.release();
    }
    assert.equal(Number((await dataSource.query('SELECT COUNT(*) AS total FROM servicos_catalogo'))[0].total), 2);
  } finally {
    if (app) await app.close();
    if (dataSource?.isInitialized) await dataSource.destroy();
    if (created) await connection.query(`DROP DATABASE \`${database}\``);
    await connection.end();
  }
});
