import 'api_service.dart';

class AdminService {
  const AdminService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> painel() {
    return _api.get('admin/painel');
  }

  Future<Map<String, dynamic>> listarUsuarios({
    String? tipo,
    String? termo,
    bool? ativo,
  }) {
    return _api.get(
      'admin/usuarios',
      queryParameters: {
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (termo != null && termo.isNotEmpty) 'termo': termo,
        if (ativo != null) 'ativo': ativo.toString(),
      },
    );
  }

  Future<Map<String, dynamic>> obterUsuario(int usuarioId) {
    return _api.get('admin/usuarios/$usuarioId');
  }

  Future<Map<String, dynamic>> atualizarStatusUsuario({
    required int usuarioId,
    required bool ativo,
  }) {
    return _api.patch(
      'admin/usuarios/$usuarioId/status',
      body: {'ativo': ativo},
    );
  }
}
