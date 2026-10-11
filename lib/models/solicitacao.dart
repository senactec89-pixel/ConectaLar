enum StatusSolicitacao {
  aguardandoResposta('aguardando_resposta'),
  aceitaAgendada('aceita_agendada'),
  recusada('recusada'),
  cancelada('cancelada'),
  conclusaoConfirmada('conclusao_confirmada');

  const StatusSolicitacao(this.valorBanco);

  final String valorBanco;

  String get rotulo => switch (this) {
    StatusSolicitacao.aguardandoResposta => 'Aguardando resposta',
    StatusSolicitacao.aceitaAgendada => 'Aceita e agendada',
    StatusSolicitacao.recusada => 'Recusada',
    StatusSolicitacao.cancelada => 'Cancelada',
    StatusSolicitacao.conclusaoConfirmada => 'Conclusão confirmada',
  };
}

class Solicitacao {
  const Solicitacao({
    required this.id,
    required this.clienteId,
    required this.profissionalId,
    required this.categoriaId,
    required this.descricao,
    required this.dataServico,
    required this.horarioServico,
    required this.precoInicial,
    required this.status,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  final int id;
  final int clienteId;
  final int profissionalId;
  final int categoriaId;
  final String descricao;
  final DateTime dataServico;
  final String horarioServico;
  final double precoInicial;
  final StatusSolicitacao status;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
}
