import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import test from 'node:test';
import mysql from 'mysql2/promise';

const enabled = process.env.CONECTALAR_MYSQL_TEST === '1';

test('MySQL real: limites persistentes, tentativas e uso unico de codigos', { skip: !enabled }, async () => {
  const host = required('CONECTALAR_TEST_DB_HOST');
  assert.ok(['127.0.0.1', 'localhost', '::1'].includes(host), 'O banco de teste deve estar em loopback.');
  const port = Number(process.env.CONECTALAR_TEST_DB_PORT ?? '3307');
  const user = required('CONECTALAR_TEST_DB_USER');
  const password = process.env.CONECTALAR_TEST_DB_PASSWORD ?? '';
  const database = `conectalar_codes_${randomBytes(8).toString('hex')}`;
  const admin = await mysql.createConnection({ host, port, user, password, connectTimeout: 3_000 });
  const envKeys = [
    'NODE_ENV', 'HOST', 'PORT', 'DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME',
    'AUTH_TOKEN_SECRET', 'MFA_SECRET_ENCRYPTION_KEY', 'EMAIL_OUTBOX_ENCRYPTION_KEY',
    'EXPOSE_EMAIL_VERIFICATION_CODE', 'EXPOSE_PASSWORD_RESET_TOKEN', 'SMTP_HOST', 'SMTP_FROM',
  ];
  const previousEnv = new Map(envKeys.map((key) => [key, process.env[key]]));
  let created = false;
  let dataSource;
  let app;

  try {
    await admin.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    created = true;
    Object.assign(process.env, {
      NODE_ENV: 'test', HOST: '127.0.0.1', PORT: '3000', DB_HOST: host,
      DB_PORT: String(port), DB_USER: user, DB_PASSWORD: password, DB_NAME: database,
      AUTH_TOKEN_SECRET: randomBytes(48).toString('base64url'),
      MFA_SECRET_ENCRYPTION_KEY: randomBytes(32).toString('hex'),
      EMAIL_OUTBOX_ENCRYPTION_KEY: randomBytes(32).toString('hex'),
      EXPOSE_EMAIL_VERIFICATION_CODE: 'true', EXPOSE_PASSWORD_RESET_TOKEN: 'true',
      SMTP_HOST: '', SMTP_FROM: '',
    });

    const [{ default: source }, { createApp }, { AuthService }, { termoAtual }] = await Promise.all([
      import('../../dist/database/data-source.js'),
      import('../../dist/app.factory.js'),
      import('../../dist/auth/auth.service.js'),
      import('../../dist/termos/termos.service.js'),
    ]);
    dataSource = source;
    await dataSource.initialize();
    await dataSource.runMigrations();
    app = await createApp();
    await app.init();
    const auth = app.get(AuthService);
    const suffix = randomUUID().replaceAll('-', '').slice(0, 12);

    const registration = await auth.cadastro({
      nome: 'Teste Limite Persistente', email: `codigos.${suffix}@example.invalid`,
      senha: 'ConectaLarTeste123!', tipo: 'cliente', aceitouTermos: true,
      versaoTermos: termoAtual.versao,
    });
    const userId = registration.usuario.id;
    const session = { id: userId, tipo: 'cliente', tokenVersion: 0 };
    let verificationCode = registration.devCode;
    assert.match(verificationCode, /^\d{6}$/);

    const wrongVerificationCode = differentCode(verificationCode);
    for (let attempt = 1; attempt <= 5; attempt++) {
      await assert.rejects(
        auth.confirmarVerificacaoEmail(session, { codigo: wrongVerificationCode }),
        (error) => error.getStatus() === (attempt === 5 ? 429 : 400),
      );
    }
    const [blockedVerification] = await dataSource.query(
      'SELECT tentativas, bloqueado_em FROM usuario_email_verificacoes WHERE usuario_id = ? ORDER BY id DESC LIMIT 1',
      [userId],
    );
    assert.equal(Number(blockedVerification.tentativas), 5);
    assert.ok(blockedVerification.bloqueado_em);

    await dataSource.query(
      'UPDATE usuarios SET email_verificacao_ultima_solicitacao = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 61 SECOND) WHERE id = ?',
      [userId],
    );
    verificationCode = (await auth.solicitarVerificacaoEmail(session)).devCode;
    assert.match(verificationCode, /^\d{6}$/);
    await dataSource.query(
      'UPDATE usuarios SET email_verificacao_ultima_solicitacao = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 61 SECOND) WHERE id = ?',
      [userId],
    );
    verificationCode = (await auth.solicitarVerificacaoEmail(session)).devCode;
    await dataSource.query(
      'UPDATE usuarios SET email_verificacao_ultima_solicitacao = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 61 SECOND) WHERE id = ?',
      [userId],
    );
    await assert.rejects(
      auth.solicitarVerificacaoEmail(session),
      (error) => error.getStatus() === 429,
    );
    await auth.confirmarVerificacaoEmail(session, { codigo: verificationCode });
    const [verificationQuota] = await dataSource.query(
      'SELECT email_verificado, email_verificacao_solicitacoes FROM usuarios WHERE id = ?',
      [userId],
    );
    assert.equal(Number(verificationQuota.email_verificado), 1);
    assert.equal(Number(verificationQuota.email_verificacao_solicitacoes), 3);

    const email = registration.usuario.email;
    const firstReset = await auth.solicitarRecuperacaoSenha({ email });
    assert.match(firstReset.devToken, /^\d{6}$/);
    const wrongResetCode = differentCode(firstReset.devToken);
    for (let attempt = 1; attempt <= 5; attempt++) {
      await assert.rejects(
        auth.confirmarRecuperacaoSenha({ email, token: wrongResetCode, novaSenha: 'NovaSenha123!A' }),
        (error) => error.getStatus() === (attempt === 5 ? 429 : 400),
      );
    }
    const [blockedReset] = await dataSource.query(
      'SELECT tentativas, bloqueado_em FROM usuario_senha_resets WHERE usuario_id = ? ORDER BY id DESC LIMIT 1',
      [userId],
    );
    assert.equal(Number(blockedReset.tentativas), 5);
    assert.ok(blockedReset.bloqueado_em);

    await dataSource.query(
      'UPDATE usuarios SET senha_reset_ultima_solicitacao = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 61 SECOND) WHERE id = ?',
      [userId],
    );
    const secondReset = await auth.solicitarRecuperacaoSenha({ email });
    const confirmations = await Promise.allSettled([
      auth.confirmarRecuperacaoSenha({ email, token: secondReset.devToken, novaSenha: 'NovaSenha123!A' }),
      auth.confirmarRecuperacaoSenha({ email, token: secondReset.devToken, novaSenha: 'NovaSenha123!A' }),
    ]);
    assert.equal(confirmations.filter((result) => result.status === 'fulfilled').length, 1);
    const rejected = confirmations.find((result) => result.status === 'rejected');
    assert.equal(rejected.reason.getStatus(), 400);

    await dataSource.query(
      'UPDATE usuarios SET senha_reset_ultima_solicitacao = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 61 SECOND) WHERE id = ?',
      [userId],
    );
    const thirdReset = await auth.solicitarRecuperacaoSenha({ email });
    assert.match(thirdReset.devToken, /^\d{6}$/);
    await dataSource.query(
      'UPDATE usuarios SET senha_reset_ultima_solicitacao = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 61 SECOND) WHERE id = ?',
      [userId],
    );
    const limitedReset = await auth.solicitarRecuperacaoSenha({ email });
    assert.deepEqual(limitedReset, { ok: true });
    const [resetQuota] = await dataSource.query(
      'SELECT senha_reset_solicitacoes FROM usuarios WHERE id = ?',
      [userId],
    );
    assert.equal(Number(resetQuota.senha_reset_solicitacoes), 3);
  } finally {
    if (app) await app.close();
    if (dataSource?.isInitialized) await dataSource.destroy();
    for (const [key, value] of previousEnv) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    if (created) await admin.query(`DROP DATABASE \`${database}\``);
    await admin.end();
  }
});

function required(name) {
  const value = process.env[name];
  assert.ok(value, `Missing required test setting ${name}`);
  return value;
}

function differentCode(code) {
  return String((Number(code) + 1) % 1_000_000).padStart(6, '0');
}
