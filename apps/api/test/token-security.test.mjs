import assert from 'node:assert/strict';
import { test } from 'node:test';
import { TokenService } from '../dist/auth/token.service.js';

test('token service verifies signed bearer tokens and rejects tampering', () => {
  process.env.AUTH_TOKEN_SECRET = 'local-test-secret-change-before-production-123456';
  const service = new TokenService();
  const token = service.createAccessToken({
    id: 42,
    tipo: 'profissional',
  });

  const payload = service.verifyAccessToken(token.accessToken);
  assert.equal(payload?.sub, 42);
  assert.equal(payload?.tipo, 'profissional');

  const tampered = `${token.accessToken.slice(0, -3)}abc`;
  assert.equal(service.verifyAccessToken(tampered), null);
});

test('token service creates short lived MFA challenge tokens', () => {
  process.env.AUTH_TOKEN_SECRET = 'local-test-secret-change-before-production-123456';
  const service = new TokenService();
  const token = service.createMfaChallengeToken({
    id: 9,
    tipo: 'administrador',
    tokenVersion: 4,
  });

  const payload = service.verifyMfaChallengeToken(token.mfaToken);
  assert.equal(payload?.sub, 9);
  assert.equal(payload?.tv, 4);
  assert.equal(payload?.purpose, 'admin_mfa');
  assert.equal(token.expiresIn, 300);

  const tampered = `${token.mfaToken.slice(0, -3)}abc`;
  assert.equal(service.verifyMfaChallengeToken(tampered), null);
});

test('admin MFA setup challenge has a separate purpose and short expiry', () => {
  process.env.AUTH_TOKEN_SECRET = 'local-test-secret-change-before-production-123456';
  const service = new TokenService();
  const token = service.createMfaSetupChallengeToken({
    id: 11,
    tipo: 'administrador',
    tokenVersion: 3,
  });
  const payload = service.verifyMfaSetupChallengeToken(token.mfaSetupToken);
  assert.equal(payload?.sub, 11);
  assert.equal(payload?.tv, 3);
  assert.equal(payload?.purpose, 'admin_mfa_setup');
  assert.equal(token.expiresIn, 600);
  assert.equal(service.verifyMfaChallengeToken(token.mfaSetupToken), null);
});
