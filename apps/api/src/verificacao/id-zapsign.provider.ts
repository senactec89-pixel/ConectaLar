import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import type { IdentidadeProvider } from './habilitacao-profissional.js';

const apiBase = 'https://api.id.zapsign.com.br/v1';
const validationHost = 'id.zapsign.com.br';
const requestTimeoutMs = 10_000;

interface ProviderValidation {
  object?: unknown;
  id?: unknown;
  type?: unknown;
  external_id?: unknown;
  status?: unknown;
  result?: unknown;
  validation_url?: unknown;
  expires_at?: unknown;
  resolved_at?: unknown;
}

@Injectable()
export class IdZapSignProvider implements IdentidadeProvider {
  get disponivel(): boolean {
    return process.env.ID_ZAPSIGN_ENABLED === 'true' &&
      Boolean(process.env.ID_ZAPSIGN_API_KEY?.trim());
  }

  async iniciar(input: { referenciaExterna: string; chaveIdempotencia: string }) {
    const response = await this.request('/validations/liveness-document-match', {
      method: 'POST',
      headers: { 'Idempotency-Key': input.chaveIdempotencia },
      body: JSON.stringify({ consent: true, external_id: input.referenciaExterna }),
    });
    const body = asProviderValidation(response);
    const url = validationUrl(body.validation_url);
    const referencia = idString(body.id);
    if (body.object !== 'validation' || !url || !referencia ||
      body.external_id !== input.referenciaExterna ||
      body.type !== 'liveness_document_match' || body.status !== 'pending') {
      throw unavailable();
    }
    return { referencia, url, expiraEm: parseDate(body.expires_at) };
  }

  async consultar(referencia: string, referenciaExterna: string) {
    const body = asProviderValidation(await this.request(
      `/validations/${encodeURIComponent(referencia)}`,
      { method: 'GET' },
    ));
    if (body.object !== 'validation' || body.id !== referencia ||
      body.external_id !== referenciaExterna ||
      body.type !== 'liveness_document_match') throw unavailable();
    const status = body.status;
    const result = body.result;
    const expirado = status === 'expired';
    const confirmado = status === 'completed' && result === 'passed';
    return {
      status: confirmado ? 'confirmada' as const
        : status === 'pending' ? 'pendente' as const
        : expirado ? 'expirada' as const
        : 'revisao_necessaria' as const,
      url: status === 'pending' ? validationUrl(body.validation_url) : null,
      expiraEm: parseDate(body.expires_at),
      resolvidaEm: parseDate(body.resolved_at) ?? (expirado ? new Date() : null),
    };
  }

  private async request(path: string, init: RequestInit): Promise<unknown> {
    const apiKey = process.env.ID_ZAPSIGN_API_KEY?.trim();
    if (!apiKey) throw unavailable();
    try {
      const response = await fetch(`${apiBase}${path}`, {
        ...init,
        headers: {
          Authorization: `Bearer ${apiKey}`,
          Accept: 'application/json',
          ...(init.body ? { 'Content-Type': 'application/json' } : {}),
          ...init.headers,
        },
        signal: AbortSignal.timeout(requestTimeoutMs),
      });
      if (!response.ok) throw unavailable();
      return await response.json() as unknown;
    } catch {
      throw unavailable();
    }
  }
}

function asProviderValidation(value: unknown): ProviderValidation {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw unavailable();
  return value as ProviderValidation;
}

function idString(value: unknown): string | null {
  return typeof value === 'string' && /^val_[A-Za-z0-9]+$/.test(value) ? value : null;
}

function validationUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === validationHost &&
      url.pathname.startsWith('/validate/') && !url.username && !url.password
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

function parseDate(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function unavailable() {
  return new ServiceUnavailableException({
    code: 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
    message: 'Nao foi possivel consultar o servico de identidade. Seu cadastro continua pendente.',
  });
}
