import 'api_service.dart';

class ClienteService {
  const ClienteService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> meuPerfil() {
    return _api.get('clientes/me');
  }

  Future<Map<String, dynamic>> atualizarMeuPerfil(Map<String, dynamic> dados) {
    return _api.put('clientes/me', body: dados);
  }

  Future<Map<String, dynamic>> listarEnderecos() {
    return _api.get('clientes/me/enderecos');
  }

  Future<Map<String, dynamic>> criarEndereco(Map<String, dynamic> dados) {
    return _api.post('clientes/me/enderecos', body: dados);
  }

  Future<Map<String, dynamic>> atualizarEndereco(
    int id,
    Map<String, dynamic> dados,
  ) {
    return _api.patch('clientes/me/enderecos/$id', body: dados);
  }

  Future<Map<String, dynamic>> removerEndereco(int id) {
    return _api.delete('clientes/me/enderecos/$id');
  }

  Future<Map<String, dynamic>> listarFavoritos({
    int pagina = 1,
    int limite = 20,
  }) {
    return _api.get(
      'clientes/me/favoritos',
      queryParameters: {'pagina': '$pagina', 'limite': '$limite'},
    );
  }

  Future<Map<String, dynamic>> consultarFavorito(int profissionalId) {
    return _api.get('clientes/me/favoritos/$profissionalId');
  }

  Future<Map<String, dynamic>> adicionarFavorito(int profissionalId) {
    return _api.post('clientes/me/favoritos/$profissionalId');
  }

  Future<Map<String, dynamic>> removerFavorito(int profissionalId) {
    return _api.delete('clientes/me/favoritos/$profissionalId');
  }
}
