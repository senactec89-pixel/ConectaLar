import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { DataSource } from 'typeorm';
import { databaseCliOptions } from '../../dist/database/database.config.js';
import { UsuarioEntity } from '../../dist/database/entities/usuario.entity.js';
import { ProfissionalPerfilEntity } from '../../dist/database/entities/profissional-perfil.entity.js';
import { AdminAuditoriaEntity } from '../../dist/database/entities/admin-auditoria.entity.js';
import { HabilitacaoService } from '../../dist/verificacao/habilitacao.service.js';

// Opt-in: creates a fresh random database on LOCAL MySQL, never uses DB_NAME.
// The supplied DB_USER needs CREATE/DROP privileges for this disposable test.
test('MySQL: migrations, audit constraint, review concurrency and rollback', {
  skip: process.env.CONECTALAR_MYSQL_SECURITY_TEST !== '1',
}, async () => {
  const host = process.env.DB_HOST ?? '127.0.0.1';
  assert.ok(['127.0.0.1', 'localhost', '::1'].includes(host));
  const database = `conectalar_security_test_${randomBytes(8).toString('hex')}`;
  assert.match(database, /^conectalar_security_test_[a-f0-9]{16}$/);
  const connection = await mysql.createConnection({ host, port: Number(process.env.DB_PORT ?? 3307),
    user: process.env.DB_USER, password: process.env.DB_PASSWORD, connectTimeout: 3000 });
  let created = false;
  let ds;
  try {
    await connection.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4`);
    created = true;
    process.env.DB_HOST = host;
    process.env.DB_NAME = database;
    ds = new DataSource({ ...databaseCliOptions(), database });
    await ds.initialize();
    await ds.runMigrations();
    const usuarios = ds.getRepository(UsuarioEntity);
    const perfis = ds.getRepository(ProfissionalPerfilEntity);
    const auditorias = ds.getRepository(AdminAuditoriaEntity);
    const titular = await usuarios.save(usuarios.create({ nome: 'Titular teste', email: 'titular@example.invalid',
      tipo: 'profissional', emailVerificado: true, ativo: true, senhaHash: 'not-a-login-hash' }));
    const administrador = await usuarios.save(usuarios.create({ nome: 'Admin teste', email: 'admin@example.invalid',
      tipo: 'administrador', emailVerificado: true, ativo: true, mfaAtivo: true, senhaHash: 'not-a-login-hash' }));
    const perfil = await perfis.save(perfis.create({ usuarioId: titular.id, descricao: 'Perfil de teste', bairro: 'Centro', verificado: true }));
    assert.equal(perfil.habilitacaoEstado, 'pendente');
    const service = new HabilitacaoService(perfis, usuarios);
    const profissional = { id: titular.id, tipo: 'profissional' };
    const admin = { id: administrador.id, tipo: 'administrador' };
    await Promise.all([service.solicitarRevisao(profissional, {}), service.solicitarRevisao(profissional, {})]);
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_revisao_solicitada' } }), 1);
    await service.analisar(admin, perfil.id, { acao: 'suspender', motivo: 'revisao_cadastral' });
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'suspenso');
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_analisada' } }), 1);

    const failingRepository = { manager: { transaction: (fn) => ds.manager.transaction((manager) => {
      const wrapper = Object.create(manager);
      wrapper.save = async (type, data) => {
        if (type === AdminAuditoriaEntity) throw new Error('test-audit-failure');
        return manager.save(type, data);
      };
      return fn(wrapper);
    }) } };
    const failingService = new HabilitacaoService(failingRepository, usuarios);
    await assert.rejects(failingService.analisar(admin, perfil.id, {
      acao: 'reabrir', motivo: 'solicitacao_titular',
    }), /test-audit-failure/);
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'suspenso');
    assert.equal((await service.minha(profissional)).habilitacao.podeAtender, false);
    await assert.rejects(ds.undoLastMigration(), /preserve the professional eligibility audit history/);
  } finally {
    if (ds?.isInitialized) await ds.destroy();
    if (created) await connection.query(`DROP DATABASE \`${database}\``);
    await connection.end();
  }
});
