import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MailService } from '../dist/auth/mail.service.js';
import { MfaService } from '../dist/auth/mfa.service.js';
import { PasswordService } from '../dist/auth/password.service.js';
import { criptografarCodigoOutbox } from '../dist/auth/email-outbox.service.js';
import { isAuthRuntimeConfigured } from '../dist/config/runtime.js';

test('password service stores scrypt hashes instead of plain text', async () => {
  const service = new PasswordService();
  const password = 'SenhaSegura123';

  const hash = await service.hash(password);

  assert.notEqual(hash, password);
  assert.match(hash, /^scrypt\$/);
  assert.equal(await service.verify(password, hash), true);
  assert.equal(await service.verify('senha-errada', hash), false);
});

test('MFA secrets are encrypted and can be recovered only with the configured key', () => {
  process.env.AUTH_TOKEN_SECRET = 'local-test-secret-change-before-production-123456';
  process.env.MFA_SECRET_ENCRYPTION_KEY = 'local-test-mfa-secret-change-before-production-123456';
  const service = new MfaService();
  const secret = service.createSecret();

  const encrypted = service.encryptSecret(secret);

  assert.notEqual(encrypted, secret);
  assert.equal(service.decryptSecret(encrypted), secret);
  assert.match(service.createOtpAuthUrl(secret, 'admin@example.invalid'), /^otpauth:\/\/totp\//);
});

test('production auth requires three distinct secrets and SMTP credentials', () => {
  const environment = {
    NODE_ENV: 'production',
    DB_HOST: 'db.example.invalid',
    DB_USER: 'app',
    DB_NAME: 'app',
    AUTH_TOKEN_SECRET: 'auth-secret-with-at-least-thirty-two-characters',
    MFA_SECRET_ENCRYPTION_KEY: 'mfa-secret-with-at-least-thirty-two-characters',
    EMAIL_OUTBOX_ENCRYPTION_KEY: 'outbox-secret-with-at-least-thirty-two-chars',
    SMTP_HOST: 'smtp.example.invalid',
    SMTP_FROM: 'ConectaLar <no-reply@example.invalid>',
    SMTP_USER: 'smtp-user',
    SMTP_PASSWORD: 'smtp-password',
  };
  assert.equal(isAuthRuntimeConfigured(environment), true);
  assert.equal(isAuthRuntimeConfigured({ ...environment, EMAIL_OUTBOX_ENCRYPTION_KEY: undefined }), false);
  assert.equal(isAuthRuntimeConfigured({ ...environment, EMAIL_OUTBOX_ENCRYPTION_KEY: environment.AUTH_TOKEN_SECRET }), false);
});

test('production outbox encryption never falls back to auth or MFA keys', () => {
  const previous = {
    NODE_ENV: process.env.NODE_ENV,
    AUTH_TOKEN_SECRET: process.env.AUTH_TOKEN_SECRET,
    MFA_SECRET_ENCRYPTION_KEY: process.env.MFA_SECRET_ENCRYPTION_KEY,
    EMAIL_OUTBOX_ENCRYPTION_KEY: process.env.EMAIL_OUTBOX_ENCRYPTION_KEY,
  };
  process.env.NODE_ENV = 'production';
  process.env.AUTH_TOKEN_SECRET = 'auth-secret-with-at-least-thirty-two-characters';
  process.env.MFA_SECRET_ENCRYPTION_KEY = 'mfa-secret-with-at-least-thirty-two-characters';
  delete process.env.EMAIL_OUTBOX_ENCRYPTION_KEY;
  try {
    assert.throws(() => criptografarCodigoOutbox('admin-invite-token'));
    process.env.EMAIL_OUTBOX_ENCRYPTION_KEY = 'outbox-secret-with-at-least-thirty-two-chars';
    assert.doesNotThrow(() => criptografarCodigoOutbox('admin-invite-token'));
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('mail service does not expose reset codes when SMTP is not configured', async () => {
  delete process.env.SMTP_HOST;
  delete process.env.SMTP_FROM;
  const service = new MailService();

  assert.equal(service.configured(), false);
  assert.equal(await service.sendPasswordResetEmail('user@example.invalid', 'token'), false);
});
