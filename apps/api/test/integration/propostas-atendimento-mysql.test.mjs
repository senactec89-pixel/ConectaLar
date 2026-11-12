import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import test from 'node:test';
import mysql from 'mysql2/promise';

test('MySQL descartavel: opcoes e propostas preservam pedidos e historico', {
  skip: process.env.CONECTALAR_MYSQL_TEST !== '1',
}, async () => {
  const host = process.env.CONECTALAR_TEST_DB_HOST;
  assert.ok(['127.0.0.1', 'localhost', '::1'].includes(host));
  const port = Number(process.env.CONECTALAR_TEST_DB_PORT);
  const user = process.env.CONECTALAR_TEST_DB_USER;
  assert.ok(user && Number.isInteger(port) && port > 0 && port <= 65535);
  const password = process.env.CONECTALAR_TEST_DB_PASSWORD ?? '';
  const database = `conectalar_it_${randomBytes(8).toString('hex')}`;
  const admin = await mysql.createConnection({ host, port, user, password, connectTimeout: 3000 });
  let ds;
  let created = false;
  try {
    await admin.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    created = true;
    Object.assign(process.env, { DB_HOST: host, DB_PORT: String(port), DB_USER: user, DB_PASSWORD: password, DB_NAME: database });
    const module = await import('../../dist/database/data-source.js');
    ds = module.default.default ?? module.default;
    await ds.initialize();
    await ds.runMigrations();
    await ds.undoLastMigration();

    await ds.query(`INSERT INTO usuarios (nome,email,email_verificado,tipo,senha_hash,ativo,mfa_ativo)
      VALUES ('Cliente Ficticio','cliente.proposta@example.invalid',1,'cliente','teste',1,0),
             ('Profissional Ficticio','profissional.proposta@example.invalid',1,'profissional','teste',1,0)`);
    const users = await ds.query("SELECT id, tipo FROM usuarios WHERE email LIKE '%.proposta@example.invalid'");
    const cliente = users.find((item) => item.tipo === 'cliente').id;
    const profissional = users.find((item) => item.tipo === 'profissional').id;
    await ds.query("INSERT INTO profissionais (usuario_id,descricao,bairro) VALUES (?,'Perfil ficticio','Centro')", [profissional]);
    const perfil = (await ds.query('SELECT id FROM profissionais WHERE usuario_id=?', [profissional]))[0].id;
    const categoria = (await ds.query("SELECT id FROM categorias WHERE nome='Limpeza'"))[0].id;
    await ds.query("INSERT INTO servicos_catalogo (categoria_id,nome,ativo) VALUES (?,'Servico ficticio',0)", [categoria]);
    const servico = (await ds.query("SELECT id FROM servicos_catalogo WHERE nome='Servico ficticio'"))[0].id;
    await ds.query(`INSERT INTO solicitacoes (cliente_id,profissional_id,categoria_id,descricao,bairro_atendimento,data_servico,horario_servico,status)
      VALUES (?,?,?,'Pedido anterior ficticio','Centro','2027-01-15','10:00','aguardando_resposta')`, [cliente, perfil, categoria]);
    const pedido = (await ds.query('SELECT id FROM solicitacoes WHERE cliente_id=?', [cliente]))[0].id;

    await ds.runMigrations();
    assert.equal((await ds.query('SELECT descricao FROM solicitacoes WHERE id=?', [pedido]))[0].descricao, 'Pedido anterior ficticio');
    assert.ok((await ds.query(`SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='solicitacoes' AND COLUMN_NAME='expira_em'`)).length === 1);
    assert.ok((await ds.query('SELECT expira_em FROM solicitacoes WHERE id=?', [pedido]))[0].expira_em);
    assert.equal(Number((await ds.query('SELECT COUNT(*) total FROM servico_catalogo_opcoes'))[0].total), 0);
    assert.equal(Number((await ds.query('SELECT COUNT(*) total FROM solicitacao_propostas_atendimento'))[0].total), 0);
    assert.ok((await ds.query(`SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='solicitacao_propostas_atendimento' AND COLUMN_NAME='expira_em'`)).length === 1);
    await ds.query("INSERT INTO servico_catalogo_opcoes (servico_catalogo_id,nome) VALUES (?,'Opcao ficticia')", [servico]);
    const option = (await ds.query('SELECT id,ativo FROM servico_catalogo_opcoes WHERE servico_catalogo_id=?', [servico]))[0];
    assert.equal(option.ativo, 0);
    await assert.rejects(ds.query("INSERT INTO servico_catalogo_opcoes (servico_catalogo_id,nome) VALUES (?,'Opcao ficticia')", [servico]));
    await assert.rejects(ds.query("INSERT INTO servico_catalogo_opcoes (servico_catalogo_id,nome) VALUES (4294967295,'Sem servico')"));
    await ds.query("INSERT INTO solicitacao_opcoes (solicitacao_id,opcao_id,nome_snapshot) VALUES (?,?,'Opcao ficticia')", [pedido, option.id]);
    await assert.rejects(ds.query("INSERT INTO solicitacao_opcoes (solicitacao_id,opcao_id,nome_snapshot) VALUES (?,?,'Duplicada')", [pedido, option.id]));
    await ds.query("UPDATE servico_catalogo_opcoes SET nome='Nome alterado' WHERE id=?", [option.id]);
    assert.equal((await ds.query('SELECT nome_snapshot FROM solicitacao_opcoes WHERE solicitacao_id=?', [pedido]))[0].nome_snapshot, 'Opcao ficticia');

    const insert = `INSERT INTO solicitacao_propostas_atendimento
      (solicitacao_id,versao,proposto_por_id,valor,data_servico,horario_servico,duracao_minutos)
      VALUES (?,?,?,?,'2027-01-15','10:00',120)`;
    await ds.query(insert, [pedido, 1, profissional, 100]);
    await assert.rejects(ds.query(insert, [pedido, 1, profissional, 100]));
    await assert.rejects(ds.query(insert, [pedido, 2, profissional, -1]));
    const first = (await ds.query('SELECT id,status FROM solicitacao_propostas_atendimento WHERE solicitacao_id=?', [pedido]))[0];
    assert.equal(first.status, 'pendente');
    await ds.query("INSERT INTO proposta_atendimento_opcoes (proposta_id,opcao_id,nome_snapshot) VALUES (?,?,'Opcao ficticia')", [first.id, option.id]);
    await assert.rejects(ds.query("UPDATE solicitacao_propostas_atendimento SET status='aceita' WHERE id=?", [first.id]));
    await ds.query("UPDATE solicitacao_propostas_atendimento SET status='recusada',respondido_por_id=?,respondido_em=CURRENT_TIMESTAMP(6) WHERE id=?", [cliente, first.id]);
    await ds.query(insert, [pedido, 2, profissional, 125]);
    const proposals = await ds.query('SELECT versao,status,valor FROM solicitacao_propostas_atendimento WHERE solicitacao_id=? ORDER BY versao', [pedido]);
    assert.deepEqual(proposals.map((item) => [item.versao, item.status, String(item.valor)]), [[1, 'recusada', '100.00'], [2, 'pendente', '125.00']]);
    const pendingProposal = (await ds.query("SELECT id FROM solicitacao_propostas_atendimento WHERE solicitacao_id=? AND status='pendente'", [pedido]))[0];
    await ds.query("UPDATE solicitacao_propostas_atendimento SET status='expirada', expira_em=CURRENT_TIMESTAMP(6) WHERE id=?", [pendingProposal.id]);
    assert.equal((await ds.query('SELECT status FROM solicitacao_propostas_atendimento WHERE id=?', [pendingProposal.id]))[0].status, 'expirada');
    await ds.query("UPDATE solicitacoes SET status='expirada' WHERE id=?", [pedido]);
    await assert.rejects(ds.undoLastMigration(), /Rollback blocked/);
    assert.equal(Number((await ds.query('SELECT COUNT(*) total FROM solicitacao_propostas_atendimento'))[0].total), 2);
  } finally {
    if (ds?.isInitialized) await ds.destroy();
    if (created) await admin.query(`DROP DATABASE \`${database}\``);
    await admin.end();
  }
});
