import 'api_service.dart';

class ProfissionalService {
  const ProfissionalService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> listar() {
    return _api.get('profissionais');
  }

  Future<Map<String, dynamic>> buscar({
    String? termo,
    String? categoriaId,
    String? bairro,
    String? cidade,
    String? uf,
    double? latitude,
    double? longitude,
    int? raioKm,
  }) {
    final filtros = <String, String>{
      if (termo != null && termo.isNotEmpty) 'termo': termo,
      if (bairro != null && bairro.isNotEmpty) 'bairro': bairro,
      if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
      if (uf != null && uf.isNotEmpty) 'uf': uf,
      if (latitude != null) 'latitude': '$latitude',
      if (longitude != null) 'longitude': '$longitude',
      if (raioKm != null) 'raioKm': '$raioKm',
      if (categoriaId != null && categoriaId.isNotEmpty)
        'categoriaId': categoriaId,
    };
    return _api.get('profissionais', queryParameters: filtros);
  }

  Future<Map<String, dynamic>> buscarPorDistancia({
    required double latitude,
    required double longitude,
    required int raioKm,
    String? termo,
    String? categoriaId,
  }) {
    return _api.post(
      'profissionais/busca',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'raioKm': raioKm,
        if (termo != null && termo.isNotEmpty) 'termo': termo,
        if (categoriaId != null && categoriaId.isNotEmpty)
          'categoriaId': categoriaId,
      },
    );
  }

  Future<Map<String, dynamic>> obter(int profissionalId) {
    return _api.get('profissionais/$profissionalId');
  }

  Future<Map<String, dynamic>> meuPerfil() {
    return _api.get('profissionais/me');
  }

  Future<Map<String, dynamic>> meuPainel() {
    return _api.get('profissionais/me/painel');
  }

  Future<Map<String, dynamic>> minhasAvaliacoes() =>
      _api.get('profissionais/me/avaliacoes');

  Future<Map<String, dynamic>> avaliacoesPublicas(int profissionalId) =>
      _api.get('profissionais/$profissionalId/avaliacoes');

  Future<Map<String, dynamic>> minhaAgenda({String? mes}) {
    return _api.get(
      'profissionais/me/agenda',
      queryParameters: {if (mes != null && mes.isNotEmpty) 'mes': mes},
    );
  }

  Future<Map<String, dynamic>> salvarMeuPerfil(Map<String, dynamic> dados) {
    return _api.put('profissionais/me', body: dados);
  }

  Future<Map<String, dynamic>> meusServicos() {
    return _api.get('profissionais/me/servicos');
  }

  Future<Map<String, dynamic>> salvarMeusServicos(
    List<Map<String, dynamic>> servicos,
  ) {
    return _api.put('profissionais/me/servicos', body: {'servicos': servicos});
  }

  Future<Map<String, dynamic>> disponibilidadePublica(int profissionalId) {
    return _api.get('profissionais/$profissionalId/disponibilidade');
  }

  Future<Map<String, dynamic>> minhaDisponibilidade() {
    return _api.get('profissionais/me/disponibilidade');
  }

  Future<Map<String, dynamic>> salvarMinhaDisponibilidade(
    List<Map<String, dynamic>> disponibilidades,
  ) {
    return _api.put(
      'profissionais/me/disponibilidade',
      body: {'disponibilidades': disponibilidades},
    );
  }
}
