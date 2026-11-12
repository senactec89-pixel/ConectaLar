import type { EntityManager } from 'typeorm';
import { SolicitacaoEventoEntity } from '../database/entities/solicitacao-evento.entity.js';
import { SolicitacaoEntity } from '../database/entities/solicitacao.entity.js';
import { SolicitacaoStatus } from '../domain/solicitacao-status.js';

export const prazoRespostaProfissionalMs = 48 * 60 * 60 * 1000;

export function calcularExpiracaoPedido(criadoEm: Date): Date {
  return new Date(criadoEm.getTime() + prazoRespostaProfissionalMs);
}

export function pedidoSemRespostaExpirou(expiraEm: Date, agora: Date): boolean {
  return expiraEm.getTime() <= agora.getTime();
}

export async function expirarPedidoSemResposta(
  manager: EntityManager,
  solicitacao: SolicitacaoEntity,
  agora = new Date(),
): Promise<boolean> {
  if (solicitacao.status !== SolicitacaoStatus.AguardandoResposta) return false;
  const respostas = await manager.query(`SELECT
    EXISTS(SELECT 1 FROM solicitacao_eventos evento
      WHERE evento.solicitacao_id=? AND evento.tipo='negociacao_iniciada') AS negociacao,
    EXISTS(SELECT 1 FROM mensagens_atendimento mensagem
      INNER JOIN profissionais profissional ON profissional.usuario_id=mensagem.autor_id
      WHERE mensagem.solicitacao_id=? AND profissional.id=?) AS mensagem_profissional`,
  [solicitacao.id, solicitacao.id, solicitacao.profissionalId]) as Array<{ negociacao: number; mensagem_profissional: number }>;
  if (Number(respostas[0]?.negociacao) === 1 || Number(respostas[0]?.mensagem_profissional) === 1) return false;

  const expiraEm = solicitacao.prazoRespostaEm ?? calcularExpiracaoPedido(solicitacao.criadoEm);
  if (!pedidoSemRespostaExpirou(expiraEm, agora)) {
    if (solicitacao.prazoRespostaEm === null) {
      solicitacao.prazoRespostaEm = expiraEm;
      await manager.save(SolicitacaoEntity, solicitacao);
    }
    return false;
  }

  const statusAnterior = solicitacao.status;
  solicitacao.prazoRespostaEm = expiraEm;
  solicitacao.status = SolicitacaoStatus.Expirada;
  await manager.save(SolicitacaoEntity, solicitacao);
  await manager.save(SolicitacaoEventoEntity, manager.create(SolicitacaoEventoEntity, {
    solicitacaoId: solicitacao.id,
    atorId: null,
    tipo: 'solicitacao_expirada',
    statusAnterior,
    statusNovo: SolicitacaoStatus.Expirada,
    motivo: 'prazo_resposta_profissional_48h',
  }));
  return true;
}
