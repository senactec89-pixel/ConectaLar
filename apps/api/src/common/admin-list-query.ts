import { BadRequestException } from '@nestjs/common';

export function optionalSearchTerm(
  query: Record<string, unknown>,
  key = 'termo',
  maxLength = 120,
): string | null {
  const value = query[key];
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw invalidFilter();
  const term = value.trim();
  if (term.length === 0) return null;
  if (term.length > maxLength) throw invalidFilter();
  return term;
}

export function optionalEnumFilter<T extends string>(
  query: Record<string, unknown>,
  key: string,
  values: readonly T[],
): T | null {
  const value = query[key];
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'string' && values.includes(value as T)) {
    return value as T;
  }
  throw invalidFilter();
}

function invalidFilter(): BadRequestException {
  return new BadRequestException({
    code: 'FILTRO_INVALIDO',
    message: 'Um ou mais filtros informados sao invalidos.',
  });
}
