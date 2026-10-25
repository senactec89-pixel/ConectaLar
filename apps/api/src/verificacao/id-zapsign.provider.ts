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
  attempts_remaining?: unknown;
}

@Injectable()
export class IdZapSignProvider implements IdentidadeProvider {
  get disponivel(): boolean {
    return process.env.ID_ZAPSIGN_ENABLED === 'true' &&
      Boolean(process.env.ID_ZAPSIGN_API_KEY?.trim());
  }

  get telefoneDisponivel(): boolean {
    return process.env.ID_ZAPSIGN_PHONE_ENABLED === 'true' &&
      Boolean(process.env.ID_ZAPSIGN_API_KEY?.trim());
  }

  async iniciar(input: { referenciaExterna: string; chaveIdempotencia: string }) {
    const response = await this.request('/validations/liveness-document-match', {
      method: 'POST',
      headers: { 'Idempotency-Key': input.chaveIdempotencia },
      body: JSON.stringify({ consent: true, external_id: input.referenciaExterna }),
    }, this.disponivel);
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
      this.disponivel,
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

  async iniciarPosseTelefone(input: {
    telefoneE164: string;
    referenciaExterna: string;
    chaveIdempotencia: string;
  }) {
    const errorCode = 'VERIFICACAO_TELEFONE_INDISPONIVEL';
    const body = asProviderValidation(await this.request('/validations/phone-ownership', {
      method: 'POST',
      headers: { 'Idempotency-Key': input.chaveIdempotencia },
      body: JSON.stringify({
        phone: input.telefoneE164,
        consent: true,
        external_id: input.referenciaExterna,
      }),
    }, this.telefoneDisponivel, errorCode), errorCode);
    const referencia = idString(body.id);
    const tentativas = numberInRange(body.attempts_remaining, 0, 3);
    const expiraEm = parseDate(body.expires_at);
    if (body.object !== 'validation' || !referencia ||
      body.external_id !== input.referenciaExterna ||
      body.type !== 'phone_ownership' || body.status !== 'pending' ||
      tentativas === null || !expiraEm) {
      throw unavailable(errorCode);
    }
    return { referencia, tentativasRestantes: tentativas, expiraEm };
  }

  async confirmarPosseTelefone(input: {
    referencia: string;
    referenciaExterna: string;
    codigo: string;
    chaveIdempotencia: string;
  }) {
    const errorCode = 'VERIFICACAO_TELEFONE_INDISPONIVEL';
    const body = asProviderValidation(await this.request(
      `/validations/${encodeURIComponent(input.referencia)}/verify`,
      {
        method: 'POST',
        headers: { 'Idempotency-Key': input.chaveIdempotencia },
        body: JSON.stringify({ code: input.codigo }),
      },
      this.telefoneDisponivel,
      errorCode,
    ), errorCode);
    const tentativas = numberInRange(body.attempts_remaining, 0, 3);
    const expiraEm = parseDate(body.expires_at);
    if (body.object !== 'validation' || body.id !== input.referencia ||
      body.external_id !== input.referenciaExterna ||
      body.type !== 'phone_ownership' || tentativas === null) {
      throw unavailable(errorCode);
    }
    const expirado = body.status === 'expired';
    const confirmado = body.status === 'completed' && body.result === 'passed';
    const rejeitado = body.status === 'completed' && body.result === 'not_passed';
    const pendente = body.status === 'pending' && body.result === null && tentativas > 0;
    const falhou = body.status === 'failed';
    if (!expirado && !confirmado && !rejeitado && !pendente && !falhou) throw unavailable(errorCode);
    return {
      status: confirmado ? 'confirmada' as const
        : pendente ? 'pendente' as const
        : expirado ? 'expirada' as const
        : 'revisao_necessaria' as const,
      tentativasRestantes: tentativas,
      expiraEm,
      resolvidaEm: parseDate(body.resolved_at) ?? (expirado || rejeitado ? new Date() : null),
    };
  }

  private async request(
    path: string,
    init: RequestInit,
    enabled: boolean,
    errorCode = 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
  ): Promise<unknown> {
    const apiKey = process.env.ID_ZAPSIGN_API_KEY?.trim();
    if (!enabled || !apiKey) throw unavailable(errorCode);
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
      if (!response.ok) throw unavailable(errorCode);
      return await response.json() as unknown;
    } catch {
      throw unavailable(errorCode);
    }
  }
}

function asProviderValidation(
  value: unknown,
  errorCode = 'VERIFICACAO_IDENTIDADE_INDISPONIVEL',
): ProviderValidation {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw unavailable(errorCode);
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

function numberInRange(value: unknown, min: number, max: number): number | null {
  return typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max
    ? value
    : null;
}

function unavailable(code = 'VERIFICACAO_IDENTIDADE_INDISPONIVEL') {
  return new ServiceUnavailableException({
    code,
    message: code === 'VERIFICACAO_TELEFONE_INDISPONIVEL'
      ? 'Nao foi possivel consultar o servico de confirmacao de telefone. Seu cadastro continua pendente.'
      : 'Nao foi possivel consultar o servico de identidade. Seu cadastro continua pendente.',
  });
}
