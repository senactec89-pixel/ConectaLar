import 'cliente_endereco.dart';

enum StatusSolicitacao {
  aguardandoResposta('aguardando_resposta'),
  aceitaAgendada('aceita_agendada'),
  recusada('recusada'),
  cancelada('cancelada'),
  conclusaoPendente('conclusao_pendente'),
  conclusaoContestada('conclusao_contestada'),
  naoComparecimentoInformado('nao_comparecimento_informado'),
  conclusaoConfirmada('conclusao_confirmada');

  const StatusSolicitacao(this.valorBanco);

  final String valorBanco;

  String get rotulo => switch (this) {
    StatusSolicitacao.aguardandoResposta => 'Aguardando resposta',
    StatusSolicitacao.aceitaAgendada => 'Aceita e agendada',
    StatusSolicitacao.recusada => 'Recusada',
    StatusSolicitacao.cancelada => 'Cancelada',
    StatusSolicitacao.conclusaoPendente => 'Aguardando confirmação',
    StatusSolicitacao.conclusaoContestada => 'Conclusão contestada',
    StatusSolicitacao.naoComparecimentoInformado =>
      'Não comparecimento informado',
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
    this.bairroAtendimento = '',
    this.enderecoProtegido = false,
    this.enderecoCompletoLiberado = false,
    this.enderecoId,
    this.enderecoAtendimento,
    this.profissionalUsuarioId = 0,
    this.servicoId,
    this.nomeServico,
    this.duracaoMinutos = 60,
    this.intervaloMinutos = 30,
    this.reagendamento,
    this.reagendamentos = const [],
    this.cancelamentoMotivo,
    this.conclusaoContestacaoMotivo,
    this.naoComparecimentoMotivo,
    this.naoComparecimentoPorId,
    this.eventos = const [],
  });

  final int id;
  final int clienteId;
  final int profissionalId;
  final int profissionalUsuarioId;
  final int? servicoId;
  final String? nomeServico;
  final int categoriaId;
  final int? enderecoId;
  final String descricao;
  final String bairroAtendimento;
  final bool enderecoProtegido;
  final bool enderecoCompletoLiberado;
  final ClienteEndereco? enderecoAtendimento;
  final DateTime dataServico;
  final String horarioServico;
  final int duracaoMinutos;
  final int intervaloMinutos;
  final Map<String, dynamic>? reagendamento;
  final List<Map<String, dynamic>> reagendamentos;
  final String? cancelamentoMotivo;
  final String? conclusaoContestacaoMotivo;
  final String? naoComparecimentoMotivo;
  final int? naoComparecimentoPorId;
  final List<Map<String, dynamic>> eventos;
  final double? precoInicial;
  final StatusSolicitacao status;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
}
