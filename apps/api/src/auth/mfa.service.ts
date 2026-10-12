import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from 'node:crypto';
import { Injectable } from '@nestjs/common';

const base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const totpPeriodSeconds = 30;

@Injectable()
export class MfaService {
  createSecret(): string {
    const bytes = randomBytes(20);
    let bits = '';
    for (const byte of bytes) bits += byte.toString(2).padStart(8, '0');
    let secret = '';
    for (let index = 0; index < bits.length; index += 5) {
      const chunk = bits.slice(index, index + 5).padEnd(5, '0');
      secret += base32Alphabet[Number.parseInt(chunk, 2)];
    }
    return secret;
  }

  createOtpAuthUrl(secret: string, email: string): string {
    const issuer = encodeURIComponent('ConectaLar');
    const label = encodeURIComponent(`ConectaLar:${email}`);
    return `otpauth://totp/${label}?secret=${secret}&issuer=${issuer}&digits=6&period=${totpPeriodSeconds}`;
  }

  encryptSecret(secret: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', encryptionKey(), iv);
    const encrypted = Buffer.concat([
      cipher.update(secret, 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();
    return `v1.${iv.toString('base64url')}.${tag.toString('base64url')}.${encrypted.toString('base64url')}`;
  }

  decryptSecret(encrypted: string): string | null {
    const parts = encrypted.split('.');
    const [version, iv, tag, value] = parts;
    if (
      parts.length !== 4 ||
      version !== 'v1' ||
      iv === undefined ||
      tag === undefined ||
      value === undefined
    ) {
      return null;
    }

    try {
      const decipher = createDecipheriv(
        'aes-256-gcm',
        encryptionKey(),
        Buffer.from(iv, 'base64url'),
      );
      decipher.setAuthTag(Buffer.from(tag, 'base64url'));
      return Buffer.concat([
        decipher.update(Buffer.from(value, 'base64url')),
        decipher.final(),
      ]).toString('utf8');
    } catch {
      return null;
    }
  }

  verifyCode(secret: string, code: string): boolean {
    if (!/^\d{6}$/.test(code)) return false;
    const counter = Math.floor(Date.now() / 1000 / totpPeriodSeconds);
    return [-1, 0, 1].some((offset) =>
      safeEqualText(code, totp(secret, counter + offset)),
    );
  }
}

function totp(secret: string, counter: number): string {
  const key = decodeBase32(secret);
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(BigInt(counter));
  const hmac = createHmac('sha1', key).update(buffer).digest();
  const offset = hmac[hmac.length - 1]! & 0x0f;
  const binary =
    ((hmac[offset]! & 0x7f) << 24) |
    (hmac[offset + 1]! << 16) |
    (hmac[offset + 2]! << 8) |
    hmac[offset + 3]!;
  return String(binary % 1_000_000).padStart(6, '0');
}

function decodeBase32(value: string): Buffer {
  let bits = '';
  for (const char of value.replace(/=+$/g, '').toUpperCase()) {
    const index = base32Alphabet.indexOf(char);
    if (index === -1) throw new Error('Invalid base32 secret.');
    bits += index.toString(2).padStart(5, '0');
  }
  const bytes: number[] = [];
  for (let index = 0; index + 8 <= bits.length; index += 8) {
    bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
  }
  return Buffer.from(bytes);
}

function encryptionKey(): Buffer {
  const configured = process.env.MFA_SECRET_ENCRYPTION_KEY;
  const fallback = process.env.AUTH_TOKEN_SECRET;
  const source =
    configured !== undefined && configured.length >= 32 ? configured : fallback;
  if (source === undefined || source.length < 32) {
    throw new Error('MFA encryption configuration is incomplete.');
  }
  return createHash('sha256').update(source, 'utf8').digest();
}

function safeEqualText(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}
