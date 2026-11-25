import type { ProfissionalServicoEntity } from '../database/entities/profissional-servico.entity.js';

export type PoliticaHabilitacaoPiloto =
  | 'fora_piloto'
  | 'experiencia_declarada'
  | 'iniciante_ou_experiencia';

export type NivelExperienciaPiloto = 'experiencia_declarada' | 'iniciante';

export type EstadoRevisaoExperienciaPiloto =
  | 'pendente'
  | 'primeira_aprovacao'
  | 'aprovada'
  | 'precisa_correcao'
  | 'inconclusiva'
  | 'suspensa';

export function habilitacaoPilotoAtiva(): boolean {
  if (process.env.CONECTALAR_HABILITACAO_PILOTO !== 'true') return false;
  const stage = process.env.CONECTALAR_STAGE;
  const database = process.env.DB_NAME;
  const host = process.env.DB_HOST;
  if (process.env.NODE_ENV === 'production') {
    return stage === 'homologacao' && database === 'conectalar_homologacao';
  }
  if (process.env.NODE_ENV === 'test') {
    return stage === 'development' && database === 'conectalar_beta_test' &&
      ['127.0.0.1', 'localhost', '::1'].includes(host ?? '');
  }
  return process.env.NODE_ENV === 'development' && stage === 'development' &&
    database === 'conectalar_dev' && ['127.0.0.1', 'localhost', '::1'].includes(host ?? '');
}

export function ofertaElegivelNoPiloto(oferta: ProfissionalServicoEntity): boolean {
  if (!habilitacaoPilotoAtiva()) return true;
  const catalogo = oferta.servicoCatalogo;
  const politica = catalogo?.politicaPiloto ?? 'fora_piloto';
  if (!oferta.ativo || oferta.servicoCatalogoId == null || !catalogo?.ativo ||
    !oferta.categoria?.ativo || catalogo.categoriaId !== oferta.categoriaId ||
    !politicaPilotoPublicavel(politica, catalogo.criterioPiloto) ||
    oferta.revisaoExperienciaEstado !== 'aprovada') return false;
  if (politica === 'experiencia_declarada') {
    return oferta.nivelExperienciaPiloto === 'experiencia_declarada';
  }
  if (politica === 'iniciante_ou_experiencia') {
    return oferta.nivelExperienciaPiloto === 'experiencia_declarada' ||
      (oferta.nivelExperienciaPiloto === 'iniciante' && oferta.inicianteConfirmadoPiloto === true);
  }
  return false;
}

export function politicaPilotoPublicavel(
  politica: PoliticaHabilitacaoPiloto | null | undefined,
  criterio: string | null | undefined,
): boolean {
  return politica !== undefined && politica !== null &&
    politica !== 'fora_piloto' && typeof criterio === 'string' &&
    criterio.trim().length >= 20;
}
