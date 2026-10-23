import 'api_service.dart';

class DenunciaService {
  const DenunciaService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> criar({
    required int solicitacaoId,
    required int denunciadoId,
    required String motivo,
    required String descricao,
  }) {
    return _api.post(
      'solicitacoes/$solicitacaoId/denuncias',
      body: {
        'denunciadoId': denunciadoId,
        'motivo': motivo,
        'descricao': descricao,
      },
    );
  }

  Future<Map<String, dynamic>> minhas({int pagina = 1, int limite = 20}) {
    return _api.get(
      'denuncias/me',
      queryParameters: {'pagina': '$pagina', 'limite': '$limite'},
    );
  }
}
