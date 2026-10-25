import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { SafeExceptionFilter } from './common/filters/safe-exception.filter.js';
import { loadConfig } from './config/environment.js';

export async function createApp() {
  const config = loadConfig();
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: false,
    bodyParser: false,
  });
  app.set('trust proxy', config.trustProxyHops);
  app.use(securityHeadersMiddleware);
  app.use(rateLimitMiddleware());
  app.enableCors({
    origin: corsOrigin,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Accept'],
  });
  app.useBodyParser('json', { limit: '8mb' });
  app.useBodyParser('urlencoded', { extended: true, limit: '100kb' });
  app.useGlobalFilters(new SafeExceptionFilter());
  return app;
}

type Next = () => void;

const authRatePolicies: Readonly<Record<string, { key: string; limit: number; windowMs: number }>> = {
  '/auth/cadastro': { key: 'cadastro', limit: 6, windowMs: 60_000 },
  '/auth/login': { key: 'login', limit: 8, windowMs: 60_000 },
  '/auth/google': { key: 'google', limit: 8, windowMs: 60_000 },
  '/auth/login/mfa': { key: 'mfa-login', limit: 6, windowMs: 60_000 },
  '/auth/admin-mfa/setup': { key: 'admin-mfa-setup', limit: 6, windowMs: 60_000 },
  '/auth/admin-mfa/confirmar': { key: 'admin-mfa-confirm', limit: 6, windowMs: 60_000 },
  '/auth/admin-convites/aceitar': { key: 'admin-invite', limit: 6, windowMs: 60_000 },
  '/auth/senha/recuperacao': { key: 'password-reset-request', limit: 3, windowMs: 60_000 },
  '/auth/senha/recuperacao/confirmar': { key: 'password-reset-confirm', limit: 6, windowMs: 60_000 },
  '/auth/email/verificacao/enviar': { key: 'email-verification-request', limit: 3, windowMs: 60_000 },
  '/auth/email/verificacao/confirmar': { key: 'email-verification-confirm', limit: 6, windowMs: 60_000 },
  '/auth/mfa/admin/setup': { key: 'admin-mfa-enroll', limit: 6, windowMs: 60_000 },
  '/auth/mfa/admin/confirmar': { key: 'admin-mfa-enroll-confirm', limit: 6, windowMs: 60_000 },
};

interface HttpRequestLike {
  readonly ip?: string;
  readonly socket?: { readonly remoteAddress?: string };
  readonly method?: string;
  readonly path?: string;
}

interface HttpResponseLike {
  setHeader(name: string, value: string): void;
  status(code: number): HttpResponseLike;
  end(body?: string): void;
}

function securityHeadersMiddleware(
  _request: HttpRequestLike,
  response: HttpResponseLike,
  next: Next,
): void {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  next();
}

function rateLimitMiddleware() {
  const windowMs = positiveInt(process.env.RATE_LIMIT_WINDOW_MS, 60_000);
  const maxRequests = positiveInt(process.env.RATE_LIMIT_MAX, 120);
  const buckets = new Map<string, { count: number; resetAt: number }>();

  return (
    request: HttpRequestLike,
    response: HttpResponseLike,
    next: Next,
  ): void => {
    const now = Date.now();
    const key = clientKey(request);
    const current = buckets.get(key);
    const bucket =
      current === undefined || current.resetAt <= now
        ? { count: 0, resetAt: now + windowMs }
        : current;

    bucket.count += 1;
    buckets.set(key, bucket);

    const authPolicy = authenticationRatePolicy(request);
    const authBucket = authPolicy === null
      ? null
      : incrementBucket(
          buckets,
          `auth:${authPolicy.key}:${key}`,
          authPolicy.limit,
          authPolicy.windowMs,
          now,
        );
    const authLimitExceeded = authPolicy !== null && authBucket !== null &&
      authBucket.count > authPolicy.limit;
    const limited = bucket.count > maxRequests || authLimitExceeded;
    const activeBucket = authBucket ?? bucket;
    const activeLimit = authPolicy?.limit ?? maxRequests;
    const retryBucket = authLimitExceeded ? authBucket : bucket;

    response.setHeader('RateLimit-Limit', String(activeLimit));
    response.setHeader('RateLimit-Remaining', String(Math.max(0, activeLimit - activeBucket.count)));
    response.setHeader('RateLimit-Reset', String(Math.ceil(activeBucket.resetAt / 1000)));

    if (limited) {
      response.setHeader('Retry-After', String(Math.max(1, Math.ceil((retryBucket.resetAt - now) / 1000))));
      response.status(429).end(JSON.stringify({
        code: 'MUITAS_REQUISICOES',
        message: 'Muitas requisicoes. Tente novamente em instantes.',
      }));
      return;
    }

    if (buckets.size > 10_000) {
      for (const [bucketKey, value] of buckets) {
        if (value.resetAt <= now) buckets.delete(bucketKey);
      }
    }

    next();
  };
}

function clientKey(request: HttpRequestLike): string {
  return request.ip ?? request.socket?.remoteAddress ?? 'unknown';
}

function incrementBucket(
  buckets: Map<string, { count: number; resetAt: number }>,
  key: string,
  limit: number,
  windowMs: number,
  now: number,
) {
  const current = buckets.get(key);
  const bucket = current === undefined || current.resetAt <= now
    ? { count: 0, resetAt: now + windowMs }
    : current;
  bucket.count += 1;
  buckets.set(key, bucket);
  return bucket;
}

function authenticationRatePolicy(request: HttpRequestLike): {
  key: string;
  limit: number;
  windowMs: number;
} | null {
  if (request.method !== 'POST') return null;
  const path = (request.path ?? '').replace(/\/+$/u, '') || '/';
  return authRatePolicies[path] ?? null;
}

function positiveInt(value: string | undefined, fallback: number): number {
  if (value === undefined) return fallback;
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function corsOrigin(
  origin: string | undefined,
  callback: (error: Error | null, allow?: boolean) => void,
): void {
  if (origin === undefined) {
    callback(null, true);
    return;
  }

  if (process.env.NODE_ENV !== 'production' && isLocalOrigin(origin)) {
    callback(null, true);
    return;
  }

  const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);

  callback(null, allowedOrigins.includes(origin));
}

function isLocalOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    return ['localhost', '127.0.0.1', '10.0.2.2'].includes(url.hostname);
  } catch {
    return false;
  }
}
