import 'api_service.dart';

class MensagemService {
  const MensagemService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> listar(
    int solicitacaoId, {
    int pagina = 1,
    int limite = 20,
  }) {
    return _api.get(
      'solicitacoes/$solicitacaoId/mensagens',
      queryParameters: {'pagina': '$pagina', 'limite': '$limite'},
    );
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
