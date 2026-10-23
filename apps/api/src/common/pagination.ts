import { BadRequestException } from '@nestjs/common';

export interface PaginationOptions {
  readonly defaultLimit?: number;
  readonly maxLimit?: number;
}

export interface PaginationInput {
  readonly pagina: number;
  readonly limite: number;
  readonly skip: number;
}

export interface PaginationMetadata {
  readonly pagina: number;
  readonly limite: number;
  readonly total: number;
  readonly totalPaginas: number;
  readonly temMais: boolean;
}

export function parsePaginationQuery(
  query: Record<string, unknown>,
  options: PaginationOptions = {},
): PaginationInput {
  const defaultLimit = options.defaultLimit ?? 20;
  const maxLimit = options.maxLimit ?? 50;
  const paginaRaw = query.pagina ?? '1';
  const limiteRaw = query.limite ?? String(defaultLimit);

  if (
    typeof paginaRaw !== 'string' ||
    !/^[1-9]\d{0,4}$/.test(paginaRaw) ||
    typeof limiteRaw !== 'string' ||
    !/^[1-9]\d{0,2}$/.test(limiteRaw)
  ) {
    throw invalidPagination();
  }

  const pagina = Number(paginaRaw);
  const limite = Number(limiteRaw);
  if (limite > maxLimit) {
    throw invalidPagination();
  }

  return {
    pagina,
    limite,
    skip: (pagina - 1) * limite,
  };
}

export function paginationMetadata(
  input: PaginationInput,
  total: number,
): PaginationMetadata {
  return {
    pagina: input.pagina,
    limite: input.limite,
    total,
    totalPaginas: Math.max(1, Math.ceil(total / input.limite)),
    temMais: input.pagina * input.limite < total,
  };
}

function invalidPagination(): BadRequestException {
  return new BadRequestException({
    code: 'PAGINACAO_INVALIDA',
    message: 'Parametros de paginacao invalidos.',
  });
}
