import 'api_service.dart';

class MensagemService {
  const MensagemService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> listar(int solicitacaoId) {
    return _api.get('solicitacoes/$solicitacaoId/mensagens');
  }

  Future<Map<String, dynamic>> enviar({
    required int solicitacaoId,
    required String texto,
  }) {
    return _api.post(
      'solicitacoes/$solicitacaoId/mensagens',
      body: {'conteudo': texto},
    );
  }
}
