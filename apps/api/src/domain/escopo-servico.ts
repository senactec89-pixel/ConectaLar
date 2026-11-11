import type { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import type { EscopoServicoSnapshot } from '../database/entities/solicitacao.entity.js';

// Uma oferta pode mudar após o pedido; a cópia registra o que foi apresentado.
export function snapshotEscopo(oferta: ProfissionalServicoEntity | null): EscopoServicoSnapshot | null {
  if (oferta === null) return null;
  return {
    inclui: [...(oferta.inclui ?? [])],
    naoInclui: [...(oferta.naoInclui ?? [])],
    opcionais: [...(oferta.opcionais ?? [])],
  };
}
