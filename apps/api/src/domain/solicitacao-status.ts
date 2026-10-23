export enum SolicitacaoStatus {
  AguardandoResposta = 'aguardando_resposta',
  AceitaAgendada = 'aceita_agendada',
  Recusada = 'recusada',
  Cancelada = 'cancelada',
  ConclusaoPendente = 'conclusao_pendente',
  ConclusaoContestada = 'conclusao_contestada',
  NaoComparecimentoInformado = 'nao_comparecimento_informado',
  ConclusaoConfirmada = 'conclusao_confirmada',
}

export const solicitacaoStatusValues = Object.values(SolicitacaoStatus);
