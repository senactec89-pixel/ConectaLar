import 'api_service.dart';

class AdminService {
  const AdminService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> painel() => _api.get('admin/painel');

  Future<Map<String, dynamic>> auditoria() =>
      _api.get('admin/painel/auditoria');

  Future<Map<String, dynamic>> usuarios({String? tipo, String? termo}) =>
      _api.get(
        'admin/usuarios',
        queryParameters: {
          if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
          if (termo != null && termo.isNotEmpty) 'termo': termo,
        },
      );

  Future<Map<String, dynamic>> listarUsuarios({
    String? tipo,
    String? termo,
    bool? ativo,
  }) => _api.get(
    'admin/usuarios',
    queryParameters: {
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
      if (ativo != null) 'ativo': ativo.toString(),
    },
  );

  Future<Map<String, dynamic>> usuario(int id) =>
      _api.get('admin/usuarios/$id');

  Future<Map<String, dynamic>> criarAdministrador({
    required String nome,
    required String email,
    required String senha,
    String? telefone,
  }) => _api.post(
    'admin/usuarios/administradores',
    body: {
      'nome': nome,
      'email': email,
      'senha': senha,
      if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
    },
  );

  Future<Map<String, dynamic>> obterUsuario(int id) => usuario(id);

  Future<Map<String, dynamic>> atualizarStatus(
    int id,
    bool ativo, {
    String? motivo,
  }) => _api.patch(
    'admin/usuarios/$id/status',
    body: {
      'ativo': ativo,
      if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
    },
  );

  Future<Map<String, dynamic>> atualizarStatusUsuario({
    required int usuarioId,
    required bool ativo,
  }) => atualizarStatus(usuarioId, ativo);

  Future<Map<String, dynamic>> documentos({String? status}) => _api.get(
    'documentos-verificacao',
    queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    },
  );

  Future<Map<String, dynamic>> analisarDocumento(
    int id,
    String status, {
    String? motivo,
  }) => _api.patch(
    'documentos-verificacao/$id/analisar',
    body: {
      'status': status,
      if (motivo != null && motivo.isNotEmpty) 'motivoRejeicao': motivo,
    },
  );

  Future<Map<String, dynamic>> denuncias() => _api.get('denuncias/moderacao');

  Future<Map<String, dynamic>> moderarDenuncia(
    int id,
    String status,
    String decisao,
  ) => _api.patch(
    'denuncias/$id/moderacao',
    body: {'status': status, 'decisao': decisao},
  );

  Future<Map<String, dynamic>> avaliacoes() => _api.get('avaliacoes/moderacao');

  Future<Map<String, dynamic>> moderarAvaliacao(int id, String status) =>
      _api.patch('avaliacoes/$id/moderacao', body: {'moderacaoStatus': status});

  Future<Map<String, dynamic>> categorias() => _api.get('categorias/admin');

  Future<Map<String, dynamic>> salvarCategoria({
    int? id,
    required String nome,
    required String icone,
    required bool ativo,
  }) => id == null
      ? _api.post(
          'categorias',
          body: {'nome': nome, 'icone': icone, 'ativo': ativo},
        )
      : _api.patch(
          'categorias/$id',
          body: {'nome': nome, 'icone': icone, 'ativo': ativo},
        );
}
