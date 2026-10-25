import { In, type EntityManager } from 'typeorm';
import { ProfissionalTelefoneVerificacaoEntity } from '../database/entities/profissional-telefone-verificacao.entity.js';

export async function invalidarVerificacoesTelefone(
  manager: EntityManager,
  usuarioId: number,
): Promise<void> {
  await manager.update(
    ProfissionalTelefoneVerificacaoEntity,
    { usuarioId, estado: In(['iniciando', 'pendente', 'confirmada', 'revisao_necessaria']) },
    { estado: 'invalidada', resolvidaEm: new Date(), tentativaEmAndamento: false },
  );
}
