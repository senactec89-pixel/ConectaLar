import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { DataSource } from 'typeorm';
import { databaseCliOptions } from '../../dist/database/database.config.js';
import { UsuarioEntity } from '../../dist/database/entities/usuario.entity.js';
import { ProfissionalPerfilEntity } from '../../dist/database/entities/profissional-perfil.entity.js';
import { AdminAuditoriaEntity } from '../../dist/database/entities/admin-auditoria.entity.js';
import { ProfissionalHabilitacaoRevisaoEntity } from '../../dist/database/entities/profissional-habilitacao-revisao.entity.js';
import { ProfissionalHabilitacaoImpedimentoEntity } from '../../dist/database/entities/profissional-habilitacao-impedimento.entity.js';
import { HabilitacaoService } from '../../dist/verificacao/habilitacao.service.js';
import { ProfissionalTelefoneVerificacaoEntity } from '../../dist/database/entities/profissional-telefone-verificacao.entity.js';
import { DuplaRevisaoHabilitacao1760140000000 } from '../../dist/database/migrations/1760140000000-DuplaRevisaoHabilitacao.js';
import { ImpedimentoRevisorHabilitacao1760141000000 } from '../../dist/database/migrations/1760141000000-ImpedimentoRevisorHabilitacao.js';
import { ProfissionalTelefoneZapSign1760134000000 } from '../../dist/database/migrations/1760134000000-ProfissionalTelefoneZapSign.js';
import { invalidarVerificacoesTelefone } from '../../dist/verificacao/telefone-verificacao.util.js';

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
    const revisoes = ds.getRepository(ProfissionalHabilitacaoRevisaoEntity);
    const impedimentos = ds.getRepository(ProfissionalHabilitacaoImpedimentoEntity);
    const verificacoesTelefone = ds.getRepository(ProfissionalTelefoneVerificacaoEntity);
    const titular = await usuarios.save(usuarios.create({ nome: 'Titular teste', email: 'titular@example.invalid',
      tipo: 'profissional', emailVerificado: true, ativo: true, senhaHash: 'not-a-login-hash' }));
    const administrador = await usuarios.save(usuarios.create({ nome: 'Admin teste', email: 'admin@example.invalid',
      tipo: 'administrador', emailVerificado: true, ativo: true, mfaAtivo: true, senhaHash: 'not-a-login-hash' }));
    const segundoAdministrador = await usuarios.save(usuarios.create({ nome: 'Segundo admin teste', email: 'admin2@example.invalid',
      tipo: 'administrador', emailVerificado: true, ativo: true, mfaAtivo: true, senhaHash: 'not-a-login-hash' }));
    const terceiroAdministrador = await usuarios.save(usuarios.create({ nome: 'Terceiro admin teste', email: 'admin3@example.invalid',
      tipo: 'administrador', emailVerificado: true, ativo: true, mfaAtivo: true, senhaHash: 'not-a-login-hash' }));
    const quartoAdministrador = await usuarios.save(usuarios.create({ nome: 'Quarto admin teste', email: 'admin4@example.invalid',
      tipo: 'administrador', emailVerificado: true, ativo: true, mfaAtivo: true, senhaHash: 'not-a-login-hash' }));
    const perfil = await perfis.save(perfis.create({ usuarioId: titular.id, descricao: 'Perfil de teste', bairro: 'Centro', verificado: true }));
    assert.equal(perfil.habilitacaoEstado, 'pendente');
    const service = new HabilitacaoService(perfis, usuarios, undefined, undefined, undefined, revisoes, impedimentos);
    const profissional = { id: titular.id, tipo: 'profissional' };
    const admin = { id: administrador.id, tipo: 'administrador' };
    const admin2 = { id: segundoAdministrador.id, tipo: 'administrador' };
    const admin3 = { id: terceiroAdministrador.id, tipo: 'administrador' };
    const admin4 = { id: quartoAdministrador.id, tipo: 'administrador' };
    await Promise.all([service.solicitarRevisao(profissional, {}), service.solicitarRevisao(profissional, {})]);
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_revisao_solicitada' } }), 1);
    await service.analisar(admin, perfil.id, { acao: 'suspender', motivo: 'revisao_cadastral' });
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'suspenso');
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_analisada' } }), 1);

    const primeiraDecisao = await service.analisar(admin, perfil.id, {
      acao: 'reabrir', motivo: 'solicitacao_titular', semConflito: true,
    });
    assert.equal(primeiraDecisao.decisaoDupla.estado, 'aguardando_segundo_revisor');
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'suspenso');
    const segundaDecisao = await service.analisar(admin2, perfil.id, {
      acao: 'reabrir', motivo: 'solicitacao_titular', semConflito: true,
      revisaoId: primeiraDecisao.decisaoDupla.revisaoId,
    });
    assert.equal(segundaDecisao.decisaoDupla.estado, 'concluida');
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'pendente');
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_voto_registrado' } }), 2);
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_decisao_dupla' } }), 1);
    assert.equal((await service.minha(profissional)).habilitacao.podeAtender, false);

    const revisaoConcorrente = await service.analisar(admin, perfil.id, {
      acao: 'iniciar_analise', motivo: 'revisao_cadastral', semConflito: true,
    });
    const resultadosConcorrentes = await Promise.allSettled([
      service.analisar(admin2, perfil.id, {
        acao: 'iniciar_analise', motivo: 'revisao_cadastral', semConflito: true,
        revisaoId: revisaoConcorrente.decisaoDupla.revisaoId,
      }),
      service.analisar(admin3, perfil.id, {
        acao: 'iniciar_analise', motivo: 'revisao_cadastral', semConflito: true,
        revisaoId: revisaoConcorrente.decisaoDupla.revisaoId,
      }),
    ]);
    assert.equal(resultadosConcorrentes.filter((resultado) => resultado.status === 'fulfilled').length, 1);
    const votoDuplicado = resultadosConcorrentes.find((resultado) => resultado.status === 'rejected');
    assert.equal(votoDuplicado?.reason?.response?.code, 'HABILITACAO_REVISAO_INDISPONIVEL');
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'em_analise');
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_voto_registrado' } }), 4);
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_decisao_dupla' } }), 2);

    const rodadaComConflito = await service.analisar(admin, perfil.id, {
      acao: 'iniciar_analise', motivo: 'revisao_cadastral', semConflito: true,
    });
    const recusa = await service.analisar(admin2, perfil.id, {
      acao: 'recusar_conflito', motivo: 'conflito_interesse',
      revisaoId: rodadaComConflito.decisaoDupla.revisaoId,
    });
    assert.equal(recusa.decisaoDupla.estado, 'revisor_impedido');
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'em_analise');
    assert.equal(await impedimentos.count({ where: { profissionalId: perfil.id, administradorId: admin2.id } }), 1);
    await assert.rejects(service.analisar(admin2, perfil.id, {
      acao: 'iniciar_analise', motivo: 'revisao_cadastral', semConflito: true,
    }), (error) => error?.response?.code === 'HABILITACAO_REVISOR_IMPEDIDO');

    const rodadaSubstituta = await service.analisar(admin3, perfil.id, {
      acao: 'reabrir', motivo: 'revisao_cadastral', semConflito: true,
    });
    const decisaoSubstituta = await service.analisar(admin4, perfil.id, {
      acao: 'reabrir', motivo: 'solicitacao_titular', semConflito: true,
      revisaoId: rodadaSubstituta.decisaoDupla.revisaoId,
    });
    assert.equal(decisaoSubstituta.decisaoDupla.estado, 'concluida');
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'pendente');
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_revisor_impedido' } }), 1);
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_voto_registrado' } }), 7);
    assert.equal(await auditorias.count({ where: { acao: 'habilitacao_decisao_dupla' } }), 3);

    const telefone = await verificacoesTelefone.save(verificacoesTelefone.create({
      usuarioId: titular.id,
      telefoneVinculado: '11999998888',
      referencia: 'val_2W7HJ9RC4XKQ0ZB58NDT3PMFY6',
      referenciaExterna: 'phone-external-test',
      chaveIdempotencia: null,
      tentativaId: null,
      chaveIdempotenciaTentativa: null,
      tentativaEmAndamento: false,
      consentimentoEm: new Date(),
      versaoAviso: 'conectalar-telefone-whatsapp-v1',
      estado: 'confirmada',
      tentativasRestantes: 0,
      expiraEm: new Date(Date.now() + 10 * 60_000),
      resolvidaEm: new Date(),
    }));
    assert.equal(Object.hasOwn(telefone, 'codigo'), false);
    const colunasTelefone = await ds.query('SHOW COLUMNS FROM profissional_telefone_verificacoes');
    assert.equal(colunasTelefone.some((coluna) => coluna.Field === 'codigo'), false);
    await invalidarVerificacoesTelefone(ds.manager, titular.id);
    assert.equal((await verificacoesTelefone.findOneByOrFail({ id: telefone.id })).estado, 'invalidada');

    const failingRepository = { manager: { transaction: (fn) => ds.manager.transaction((manager) => {
      const wrapper = Object.create(manager);
      wrapper.save = async (type, data) => {
        if (type === AdminAuditoriaEntity) throw new Error('test-audit-failure');
        return manager.save(type, data);
      };
      return fn(wrapper);
    }) } };
    const failingService = new HabilitacaoService(failingRepository, usuarios,
      undefined, undefined, undefined, revisoes, impedimentos);
    await service.analisar(admin, perfil.id, { acao: 'suspender', motivo: 'revisao_cadastral' });
    const revisaoAuditoriaFalha = await service.analisar(admin, perfil.id, {
      acao: 'reabrir', motivo: 'solicitacao_titular', semConflito: true,
    });
    await assert.rejects(failingService.analisar(admin2, perfil.id, {
      acao: 'reabrir', motivo: 'solicitacao_titular', semConflito: true,
      revisaoId: revisaoAuditoriaFalha.decisaoDupla.revisaoId,
    }), /test-audit-failure/);
    assert.equal((await perfis.findOneByOrFail({ id: perfil.id })).habilitacaoEstado, 'suspenso');
    assert.equal((await revisoes.findOneByOrFail({ id: revisaoAuditoriaFalha.decisaoDupla.revisaoId })).estado,
      'aguardando_segundo_revisor');
    assert.equal((await service.minha(profissional)).habilitacao.podeAtender, false);
    const queryRunner = ds.createQueryRunner();
    try {
      await assert.rejects(
        new ImpedimentoRevisorHabilitacao1760141000000().down(queryRunner),
        /preserve reviewer conflict and attestation history/,
      );
      await assert.rejects(
        new DuplaRevisaoHabilitacao1760140000000().down(queryRunner),
        /preserve the administrative double-review history/,
      );
      await assert.rejects(
        new ProfissionalTelefoneZapSign1760134000000().down(queryRunner),
        /preserve phone verification records/,
      );
    } finally {
      await queryRunner.release();
    }
  } finally {
    if (ds?.isInitialized) await ds.destroy();
    if (created) await connection.query(`DROP DATABASE \`${database}\``);
    await connection.end();
  }
});
