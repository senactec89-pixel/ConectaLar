import type { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';
import type { ServicoSolicitacaoSnapshot } from '../database/entities/solicitacao.entity.js';

export function criarSnapshotServico(oferta: ProfissionalServicoEntity | null): ServicoSolicitacaoSnapshot | null {
  if (oferta === null) return null;
  const catalogo = oferta.servicoCatalogo;
  return {
    categoriaId: oferta.categoriaId,
    nomeCategoria: oferta.categoria?.nome ?? null,
    servicoCatalogoId: oferta.servicoCatalogoId ?? null,
    nomeServico: catalogo?.nome ?? oferta.nome,
    descricao: catalogo?.descricao ?? null,
    inclusoes: catalogo?.inclusoes ?? null,
    exclusoes: catalogo?.exclusoes ?? null,
  };
}
