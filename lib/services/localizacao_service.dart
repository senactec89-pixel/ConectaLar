import 'api_service.dart';

class LocalizacaoService {
  const LocalizacaoService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> consultarCep(String cep) {
    final somenteNumeros = cep.replaceAll(RegExp(r'\D'), '');
    return _api.get('localizacao/cep/$somenteNumeros');
  }
}
