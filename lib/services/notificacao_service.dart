import 'api_service.dart';

class NotificacaoService {
  const NotificacaoService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> listar({
    bool apenasNaoLidas = false,
    int pagina = 1,
    int limite = 20,
  }) {
    return _api.get(
      'notificacoes/me',
      queryParameters: {
        if (apenasNaoLidas) 'naoLidas': 'true',
        'pagina': '$pagina',
        'limite': '$limite',
      },
    );
  }

  Future<Map<String, dynamic>> resumo() {
    return _api.get('notificacoes/me/resumo');
  }

  Future<Map<String, dynamic>> marcarComoLida(int id) {
    return _api.patch('notificacoes/$id/lida');
  }

  Future<Map<String, dynamic>> marcarTodasComoLidas() {
    return _api.patch('notificacoes/me/lidas');
  }
}
