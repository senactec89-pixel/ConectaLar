import 'api_service.dart';

class CategoriaService {
  const CategoriaService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> listar() {
    return _api.get('categorias');
  }

  Future<List<Map<String, dynamic>>> servicos(int categoriaId) async {
    final resultados = <Map<String, dynamic>>[];
    var pagina = 1;
    while (true) {
      final response = await _api.get(
        'categorias/$categoriaId/servicos',
        queryParameters: {'pagina': '$pagina', 'limite': '100'},
      );
      resultados.addAll(
        (response['servicos'] as List? ?? const [])
            .whereType<Map<String, dynamic>>(),
      );
      final paginacao = response['paginacao'];
      if (paginacao is! Map || paginacao['temMais'] != true) break;
      if (++pagina > 100) {
        throw const ApiException('Lista de serviços muito extensa.');
      }
    }
    return resultados;
  }

  Future<List<Map<String, dynamic>>> opcoes(
    int categoriaId,
    int servicoId,
  ) async {
    final resultados = <Map<String, dynamic>>[];
    var pagina = 1;
    while (true) {
      final response = await _api.get(
        'categorias/$categoriaId/servicos/$servicoId/opcoes',
        queryParameters: {'pagina': '$pagina', 'limite': '100'},
      );
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
      resultados.addAll(itens.cast<Map<String, dynamic>>());
      final paginacao = response['paginacao'];
      if (paginacao is! Map || paginacao['temMais'] != true) break;
      if (++pagina > 100) {
        throw const FormatException('Lista de opcoes muito extensa.');
      }
    }
    return resultados;
  }
}
