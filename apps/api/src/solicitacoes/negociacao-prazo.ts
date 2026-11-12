import type { EntityManager } from 'typeorm';
import { SolicitacaoEventoEntity } from '../database/entities/solicitacao-evento.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';

export const prazoNegociacaoInativaMs = 96 * 60 * 60 * 1000;

export function calcularExpiracaoNegociacao(atividadeEm: Date): Date {
  return new Date(atividadeEm.getTime() + prazoNegociacaoInativaMs);
}

export async function expirarNegociacaoInativa(
  manager: EntityManager,
  solicitacao: SolicitacaoEntity,
  agora = new Date(),
): Promise<boolean> {
  if (
    solicitacao.status !== SolicitacaoStatus.AguardandoResposta ||
    solicitacao.prazoInatividadeEm == null ||
    solicitacao.prazoInatividadeEm.getTime() > agora.getTime()
  ) {
    return false;
  }

  const propostasPendentes = await manager.query(
    `SELECT EXISTS(SELECT 1 FROM solicitacao_propostas_atendimento
      WHERE solicitacao_id=? AND status='pendente') AS pendente`,
    [solicitacao.id],
  ) as Array<{ pendente: number | string }>;
  if (Number(propostasPendentes[0]?.pendente) === 1) return false;

  const statusAnterior = solicitacao.status;
  solicitacao.status = SolicitacaoStatus.NegociacaoExpirada;
  await manager.save(SolicitacaoEntity, solicitacao);
  await manager.save(
    SolicitacaoEventoEntity,
    manager.create(SolicitacaoEventoEntity, {
      solicitacaoId: solicitacao.id,
      atorId: null,
      tipo: 'negociacao_expirada',
      statusAnterior,
      statusNovo: SolicitacaoStatus.NegociacaoExpirada,
      motivo: 'inatividade_96h',
    }),
  );
  return true;
}
