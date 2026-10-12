import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MailService } from '../dist/auth/mail.service.js';
import { MfaService } from '../dist/auth/mfa.service.js';
import { PasswordService } from '../dist/auth/password.service.js';

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

test('mail service does not expose reset tokens when SMTP is not configured', async () => {
  delete process.env.SMTP_HOST;
  delete process.env.SMTP_FROM;
  const service = new MailService();

  assert.equal(service.configured(), false);
  assert.equal(await service.sendPasswordResetEmail('user@example.invalid', 'token'), false);
});
