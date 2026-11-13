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

export function escoposIguais(a: EscopoServicoSnapshot, b: EscopoServicoSnapshot): boolean {
  return (['inclui', 'naoInclui', 'opcionais'] as const).every((campo) =>
    a[campo].length === b[campo].length && a[campo].every((item, i) => item === b[campo][i]),
  );
}

export function ofertasEquivalentes(a: ProfissionalServicoEntity, b: ProfissionalServicoEntity): boolean {
  return a.id === b.id && b.ativo && a.nome === b.nome &&
    a.categoriaId === b.categoriaId && a.precoInicial === b.precoInicial &&
    a.duracaoMinutos === b.duracaoMinutos && a.intervaloMinutos === b.intervaloMinutos &&
    escoposIguais(snapshotEscopo(a)!, snapshotEscopo(b)!);
}
