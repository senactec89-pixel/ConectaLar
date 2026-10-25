import { createHmac, timingSafeEqual } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { UsuarioEntity } from '../database/entities/usuario.entity.js';
import { UsuarioTipo } from '../domain/usuario-tipo.js';

const tokenTtlSeconds = 60 * 60;

interface AccessTokenPayload {
  readonly sub: number;
  readonly tipo: UsuarioTipo;
  readonly tv: number;
  readonly iat: number;
  readonly exp: number;
}

interface MfaChallengePayload {
  readonly sub: number;
  readonly tv: number;
  readonly purpose: 'admin_mfa';
  readonly iat: number;
  readonly exp: number;
}

interface MfaSetupChallengePayload {
  readonly sub: number;
  readonly tv: number;
  readonly purpose: 'admin_mfa_setup';
  readonly iat: number;
  readonly exp: number;
}

@Injectable()
export class TokenService {
  createAccessToken(usuario: UsuarioEntity): {
    accessToken: string;
    tokenType: 'Bearer';
    expiresIn: number;
  } {
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      sub: usuario.id,
      tipo: usuario.tipo,
      tv: usuario.tokenVersion ?? 0,
      iat: now,
      exp: now + tokenTtlSeconds,
    };

    const header = encode({ alg: 'HS256', typ: 'JWT' });
    const body = encode(payload);
    const signature = sign(`${header}.${body}`, tokenSecret());

    return {
      accessToken: `${header}.${body}.${signature}`,
      tokenType: 'Bearer',
      expiresIn: tokenTtlSeconds,
    };
  }

  verifyAccessToken(token: string): AccessTokenPayload | null {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const [header, body, signature] = parts;
    if (
      header === undefined ||
      body === undefined ||
      signature === undefined ||
      !signatureMatches(`${header}.${body}`, signature)
    ) {
      return null;
    }

    const headerValue = decodeJson(header);
    if (
      !isRecord(headerValue) ||
      headerValue.alg !== 'HS256' ||
      headerValue.typ !== 'JWT'
    ) {
      return null;
    }

    const payload = decodeJson(body);
    if (!isAccessTokenPayload(payload)) {
      return null;
    }

    const now = Math.floor(Date.now() / 1000);
    if (payload.exp <= now) {
      return null;
    }

    return payload;
  }

  createMfaChallengeToken(usuario: UsuarioEntity): {
    mfaToken: string;
    expiresIn: number;
  } {
    const expiresIn = 5 * 60;
    const now = Math.floor(Date.now() / 1000);
    const payload: MfaChallengePayload = {
      sub: usuario.id,
      tv: usuario.tokenVersion ?? 0,
      purpose: 'admin_mfa',
      iat: now,
      exp: now + expiresIn,
    };

    const header = encode({ alg: 'HS256', typ: 'JWT' });
    const body = encode(payload);
    const signature = sign(`${header}.${body}`, tokenSecret());

    return {
      mfaToken: `${header}.${body}.${signature}`,
      expiresIn,
    };
  }

  verifyMfaChallengeToken(token: string): MfaChallengePayload | null {
    const payload = verifySignedPayload(token);
    if (!isMfaChallengePayload(payload)) {
      return null;
    }

    const now = Math.floor(Date.now() / 1000);
    if (payload.exp <= now) {
      return null;
    }

    return payload;
  }

  createMfaSetupChallengeToken(usuario: UsuarioEntity): {
    mfaSetupToken: string;
    expiresIn: number;
  } {
    const expiresIn = 10 * 60;
    const now = Math.floor(Date.now() / 1000);
    const payload: MfaSetupChallengePayload = {
      sub: usuario.id,
      tv: usuario.tokenVersion ?? 0,
      purpose: 'admin_mfa_setup',
      iat: now,
      exp: now + expiresIn,
    };
    const header = encode({ alg: 'HS256', typ: 'JWT' });
    const body = encode(payload);
    const signature = sign(`${header}.${body}`, tokenSecret());
    return { mfaSetupToken: `${header}.${body}.${signature}`, expiresIn };
  }

  verifyMfaSetupChallengeToken(token: string): MfaSetupChallengePayload | null {
    const payload = verifySignedPayload(token);
    if (!isMfaSetupChallengePayload(payload)) return null;
    if (payload.exp <= Math.floor(Date.now() / 1000)) return null;
    return payload;
  }
}

function encode(value: unknown): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(value: string, secret: string): string {
  return createHmac('sha256', secret).update(value).digest('base64url');
}

function signatureMatches(value: string, signature: string): boolean {
  const expected = Buffer.from(sign(value, tokenSecret()), 'base64url');
  const received = Buffer.from(signature, 'base64url');
  return (
    expected.length === received.length && timingSafeEqual(expected, received)
  );
}

function verifySignedPayload(token: string): unknown {
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  const [header, body, signature] = parts;
  if (
    header === undefined ||
    body === undefined ||
    signature === undefined ||
    !signatureMatches(`${header}.${body}`, signature)
  ) {
    return null;
  }

  const headerValue = decodeJson(header);
  if (
    !isRecord(headerValue) ||
    headerValue.alg !== 'HS256' ||
    headerValue.typ !== 'JWT'
  ) {
    return null;
  }

  return decodeJson(body);
}

function decodeJson(value: string): unknown {
  try {
    return JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as unknown;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isAccessTokenPayload(value: unknown): value is AccessTokenPayload {
  return (
    isRecord(value) &&
    Number.isSafeInteger(value.sub) &&
    typeof value.tipo === 'string' &&
    Object.values(UsuarioTipo).includes(value.tipo as UsuarioTipo) &&
    Number.isSafeInteger(value.tv) &&
    Number.isSafeInteger(value.iat) &&
    Number.isSafeInteger(value.exp)
  );
}

function isMfaChallengePayload(value: unknown): value is MfaChallengePayload {
  return (
    isRecord(value) &&
    Number.isSafeInteger(value.sub) &&
    Number.isSafeInteger(value.tv) &&
    value.purpose === 'admin_mfa' &&
    Number.isSafeInteger(value.iat) &&
    Number.isSafeInteger(value.exp)
  );
}

function isMfaSetupChallengePayload(
  value: unknown,
): value is MfaSetupChallengePayload {
  return (
    isRecord(value) &&
    Number.isSafeInteger(value.sub) &&
    Number.isSafeInteger(value.tv) &&
    value.purpose === 'admin_mfa_setup' &&
    Number.isSafeInteger(value.iat) &&
    Number.isSafeInteger(value.exp)
  );
}

function tokenSecret(): string {
  const secret = process.env.AUTH_TOKEN_SECRET;
  if (secret === undefined || secret.length < 32) {
    throw new Error('Authentication configuration is incomplete.');
  }

  return secret;
}
