import 'api_service.dart';

class ServicoService {
  const ServicoService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> solicitar(Map<String, dynamic> dados) {
    return _api.post('solicitacoes', body: dados);
  }

  Future<Map<String, dynamic>> minhas() {
    return _api.get('solicitacoes/me');
  }

  Future<Map<String, dynamic>> obter(int solicitacaoId) {
    return _api.get('solicitacoes/$solicitacaoId');
  }

  Future<Map<String, dynamic>> aceitar(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/aceitar');
  }

  Future<Map<String, dynamic>> recusar(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/recusar');
  }

  Future<Map<String, dynamic>> cancelar(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/cancelar');
  }

  Future<Map<String, dynamic>> concluir(int solicitacaoId) {
    return _api.patch('solicitacoes/$solicitacaoId/concluir');
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
}
