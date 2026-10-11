import 'api_service.dart';

class VerificacaoService {
  const VerificacaoService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> enviarDocumento({
    required String tipoDocumento,
    String? referenciaArquivo,
    String? arquivoBase64,
    String? mimeType,
    String? nomeArquivo,
    String? observacao,
  }) {
    return _api.post(
      'profissionais/me/documentos',
      body: {
        'tipoDocumento': tipoDocumento,
        'referenciaArquivo': ?referenciaArquivo,
        'arquivoBase64': ?arquivoBase64,
        'mimeType': ?mimeType,
        'nomeArquivo': ?nomeArquivo,
        'observacao': ?observacao,
      },
    );
  }

  Future<Map<String, dynamic>> meusDocumentos() {
    return _api.get('profissionais/me/documentos');
  }
}
