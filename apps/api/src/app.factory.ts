import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { SafeExceptionFilter } from './common/filters/safe-exception.filter.js';

export async function createApp() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: false,
    bodyParser: false,
  });
  app.use(securityHeadersMiddleware);
  app.use(rateLimitMiddleware());
  app.enableCors({
    origin: corsOrigin,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Accept'],
  });
  app.useBodyParser('json', false, { limit: '8mb' });
  app.useBodyParser('urlencoded', false, { extended: true, limit: '100kb' });
  app.useGlobalFilters(new SafeExceptionFilter());
  return app;
}

type Next = () => void;

interface HttpRequestLike {
  readonly ip?: string;
  readonly socket?: { readonly remoteAddress?: string };
  readonly headers?: Record<string, string | string[] | undefined>;
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
    response.setHeader('RateLimit-Limit', String(maxRequests));
    response.setHeader('RateLimit-Remaining', String(Math.max(0, maxRequests - bucket.count)));
    response.setHeader('RateLimit-Reset', String(Math.ceil(bucket.resetAt / 1000)));

    if (bucket.count > maxRequests) {
      response.status(429).end(
        JSON.stringify({
          code: 'MUITAS_REQUISICOES',
          message: 'Muitas requisicoes. Tente novamente em instantes.',
        }),
      );
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
  const forwarded = request.headers?.['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim().length > 0) {
    return forwarded.split(',')[0]?.trim() ?? 'unknown';
  }

  return request.ip ?? request.socket?.remoteAddress ?? 'unknown';
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
