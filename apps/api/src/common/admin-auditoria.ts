import type { EntityManager } from 'typeorm';
import { AdminAuditoriaEntity } from '../database/entities/admin-auditoria.entity.js';
import { AdminAuditoriaAcao } from '../domain/admin-auditoria-acao.js';

interface RegistrarAuditoriaInput {
  readonly atorId: number;
  readonly acao: AdminAuditoriaAcao;
  readonly alvoTipo: string;
  readonly alvoId: number;
  readonly detalhe: Readonly<Record<string, unknown>>;
}

export async function registrarAuditoriaAdmin(
  manager: EntityManager,
  input: RegistrarAuditoriaInput,
): Promise<void> {
  const detalhe = JSON.stringify(input.detalhe);
  if (detalhe.length > 32_000) {
    throw new Error('Administrative audit detail exceeds its allowed size.');
  }

  const repository = manager.getRepository(AdminAuditoriaEntity);
  await repository.save(repository.create({ ...input, detalhe }));
}
