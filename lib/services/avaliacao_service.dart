import 'dart:typed_data';

import 'api_service.dart';

class AvaliacaoService {
  const AvaliacaoService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> listarDaSolicitacao(int solicitacaoId) {
    return _api.get('solicitacoes/$solicitacaoId/avaliacoes');
  }

  Future<Map<String, dynamic>> avaliarProfissional({
    required int solicitacaoId,
    required int nota,
    String? comentario,
    List<int> fotoIds = const [],
  }) {
    return _api.post(
      'solicitacoes/$solicitacaoId/avaliacoes/profissional',
      body: {
        'nota': nota,
        'comentario': ?comentario,
        if (fotoIds.isNotEmpty) 'fotoIds': fotoIds,
      },
    );
  }

  Future<int> enviarFoto({
    required int solicitacaoId,
    required String nomeArquivo,
    required Uint8List bytes,
  }) async {
    final response = await _api.postMultipart(
      'solicitacoes/$solicitacaoId/avaliacoes/fotos',
      fieldName: 'arquivo',
      fileName: nomeArquivo,
      bytes: bytes,
    );
    final foto = response['foto'];
    if (foto is! Map<String, dynamic> || foto['id'] is! num) {
      throw const ApiException('Nao foi possivel preparar a foto.');
    }
    return (foto['id'] as num).toInt();
  }

  Future<void> removerFotoTemporaria({
    required int solicitacaoId,
    required int fotoId,
  }) async {
    await _api.delete('solicitacoes/$solicitacaoId/avaliacoes/fotos/$fotoId');
  }

  Future<Map<String, dynamic>> avaliarCliente({
    required int solicitacaoId,
    required int nota,
    String? comentario,
  }) {
    return _api.post(
      'solicitacoes/$solicitacaoId/avaliacoes/cliente',
      body: {'nota': nota, 'comentario': ?comentario},
    );
  }
}
