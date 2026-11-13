import 'api_service.dart';

class ServicoService {
  const ServicoService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> solicitar(Map<String, dynamic> dados) {
    return _api.post('solicitacoes', body: dados);
  }

  Future<Map<String, dynamic>> minhas({int pagina = 1, int limite = 20}) {
    return _api.get(
      'solicitacoes/me',
      queryParameters: {'pagina': '$pagina', 'limite': '$limite'},
    );
  }

  Future<Map<String, dynamic>> obter(int solicitacaoId) {
    return _api.get('solicitacoes/$solicitacaoId');
  }

  Future<Map<String, dynamic>> aceitar(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/aceitar');
  }

  Future<List<Map<String, dynamic>>> opcoes(int id) async {
    final response = await _api.get('solicitacoes/$id/opcoes');
    final itens = response['opcoes'];
    if (itens is! List ||
        itens.any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['id'] is! int ||
              item['nome'] is! String,
        )) {
      throw const FormatException('Resposta de opcoes invalida.');
    }
    return itens.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> iniciarNegociacao(int id) =>
      _api.post('solicitacoes/$id/negociacao');

  Future<Map<String, dynamic>> encerrarNegociacao(
    int id, {
    required String motivo,
  }) => _api.patch(
    'solicitacoes/$id/encerrar-negociacao',
    body: {'motivo': motivo},
  );

  Future<Map<String, dynamic>> aceitarOuNegociar(int id) async {
    final selecionadas = await opcoes(id);
    if (selecionadas.isEmpty) return aceitar(id);
    return iniciarNegociacao(id);
  }

  Future<Map<String, dynamic>> propostas(int id, {int pagina = 1}) => _api.get(
    'solicitacoes/$id/propostas-atendimento',
    queryParameters: {'pagina': '$pagina', 'limite': '100'},
  );

  Future<Map<String, dynamic>> enviarProposta(
    int id,
    Map<String, dynamic> dados,
  ) => _api.post('solicitacoes/$id/propostas-atendimento', body: dados);

  Future<Map<String, dynamic>> recusarProposta(int id, int propostaId) =>
      _api.patch(
        'solicitacoes/$id/propostas-atendimento/$propostaId/responder',
        body: {'aceitar': false},
      );

  Future<Map<String, dynamic>> confirmarProposta(int id, int propostaId) =>
      _api.patch(
        'solicitacoes/$id/propostas-atendimento/$propostaId/responder',
        body: {'aceitar': true},
      );

  Future<Map<String, dynamic>> recusar(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/recusar');
  }

  Future<Map<String, dynamic>> proporAntesAceite(
    int solicitacaoId, {
    String? dataServico,
    String? horarioServico,
    String? escopo,
  }) {
    final body = <String, dynamic>{};
    if (dataServico != null) body['dataServico'] = dataServico;
    if (horarioServico != null) body['horarioServico'] = horarioServico;
    if (escopo != null) body['escopo'] = escopo;
    return _api.post('solicitacoes/$solicitacaoId/propostas', body: body);
  }

  Future<Map<String, dynamic>> responderPropostaAntesAceite(
    int solicitacaoId,
    int propostaId, {
    required bool aceitar,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/propostas/$propostaId/responder',
      body: {'aceitar': aceitar},
    );
  }

  Future<Map<String, dynamic>> cancelar(
    int solicitacaoId, {
    required String motivo,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/cancelar',
      body: {'motivo': motivo},
    );
  }

  Future<Map<String, dynamic>> concluir(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/concluir');
  }

  Future<Map<String, dynamic>> confirmarConclusao(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/conclusao/confirmar');
  }

  Future<Map<String, dynamic>> contestarConclusao(
    int solicitacaoId, {
    required String motivo,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/conclusao/contestar',
      body: {'motivo': motivo},
    );
  }

  Future<Map<String, dynamic>> informarNaoComparecimento(
    int solicitacaoId, {
    required String motivo,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/nao-comparecimento',
      body: {'motivo': motivo},
    );
  }

  Future<Map<String, dynamic>> contestarNaoComparecimento(
    int solicitacaoId, {
    required String motivo,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/nao-comparecimento/contestar',
      body: {'motivo': motivo},
    );
  }

  Future<Map<String, dynamic>> proporReagendamento(
    int solicitacaoId, {
    required String dataServico,
    required String horarioServico,
    required String motivo,
  }) {
    return _api.post(
      'solicitacoes/$solicitacaoId/reagendamento',
      body: {
        'dataServico': dataServico,
        'horarioServico': horarioServico,
        'motivo': motivo,
      },
    );
  }

  Future<Map<String, dynamic>> responderReagendamento(
    int solicitacaoId, {
    required bool aceitar,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/reagendamento/responder',
      body: {'aceitar': aceitar},
    );
  }

  Future<Map<String, dynamic>> proporOrcamento(
    int solicitacaoId, {
    required double valor,
    required String descricao,
  }) {
    return _api.post(
      'solicitacoes/$solicitacaoId/orcamentos',
      body: {'valor': valor, 'descricao': descricao},
    );
  }

  Future<Map<String, dynamic>> responderOrcamento(
    int solicitacaoId, {
    required bool aceitar,
  }) {
    return _api.patch(
      'solicitacoes/$solicitacaoId/orcamentos/responder',
      body: {'aceitar': aceitar},
    );
  }
}
