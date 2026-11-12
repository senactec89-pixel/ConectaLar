import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { importarCatalogoProposto } from '../../scripts/catalogo-proposto.mjs';

test('MySQL real: carga proposta e idempotente e preserva servicos existentes', { skip: process.env.CONECTALAR_MYSQL_TEST !== '1' }, async () => {
  const host = process.env.CONECTALAR_TEST_DB_HOST;
  assert.ok(['127.0.0.1', 'localhost', '::1'].includes(host));
  const port = Number(process.env.CONECTALAR_TEST_DB_PORT ?? '3307');
  const user = process.env.CONECTALAR_TEST_DB_USER;
  assert.ok(user && Number.isInteger(port) && port > 0 && port <= 65535);
  const password = process.env.CONECTALAR_TEST_DB_PASSWORD ?? '';
  const database = `conectalar_it_${randomBytes(8).toString('hex')}`;
  const admin = await mysql.createConnection({ host, port, user, password, connectTimeout: 3000 });
  let db;
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
    db = await mysql.createConnection({ host, port, user, password, database });
    await db.query("INSERT INTO servicos_catalogo (categoria_id,nome,descricao,ativo) SELECT id,'Montagem de cadeira','Texto da equipe',1 FROM categorias WHERE nome='Manutencao'");
    assert.deepEqual(await importarCatalogoProposto(db), { propostos: 37, criados: 36 });
    assert.deepEqual(await importarCatalogoProposto(db), { propostos: 37, criados: 0 });
    const [rows] = await db.query('SELECT c.nome AS categoria,s.nome,s.descricao,s.ativo FROM servicos_catalogo s JOIN categorias c ON c.id=s.categoria_id');
    assert.equal(rows.length, 37);
    assert.equal(rows.filter((row) => row.ativo === 1).length, 1);
    assert.deepEqual(rows.find((row) => row.nome === 'Montagem de cadeira'), { categoria: 'Manutencao', nome: 'Montagem de cadeira', descricao: 'Texto da equipe', ativo: 1 });
    assert.equal(rows.filter((row) => row.categoria === 'Manutencao').length, 10);
    const padrao = rows.find((row) => row.nome === 'Limpeza residencial padrao');
    assert.match(padrao.descricao, /cozinha e banheiro/);
    await db.query("UPDATE categorias SET nome='Limpeza alterada' WHERE nome='Limpeza'");
    await assert.rejects(importarCatalogoProposto(db), /Categorias do catalogo proposto nao encontradas/);
    assert.equal((await db.query('SELECT COUNT(*) AS total FROM servicos_catalogo'))[0][0].total, 37);
  } finally {
    if (db) await db.end();
    if (ds?.isInitialized) await ds.destroy();
    if (created) await admin.query(`DROP DATABASE \`${database}\``);
    await admin.end();
  }
});
