import 'api_service.dart';

class AdminService {
  const AdminService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> habilitacoes({
    int pagina = 1,
    String? termo,
    String? estado,
  }) => _api.get(
    'admin/profissionais/habilitacoes',
    queryParameters: {
      'pagina': '$pagina',
      if (termo != null && termo.isNotEmpty) 'termo': termo,
      if (estado != null && estado.isNotEmpty) 'estado': estado,
    },
  );

  Future<Map<String, dynamic>> analisarHabilitacao(
    int id,
    String acao,
    String motivo,
  ) => _api.patch(
    'admin/profissionais/$id/habilitacao',
    body: {'acao': acao, 'motivo': motivo},
  );

  Future<Map<String, dynamic>> painel() => _api.get('admin/painel');

  Future<Map<String, dynamic>> auditoria({
    int pagina = 1,
    String? termo,
    String? acao,
    String? alvoTipo,
  }) => _api.get(
    'admin/painel/auditoria',
    queryParameters: {
      'pagina': '$pagina',
      if (termo != null && termo.isNotEmpty) 'termo': termo,
      if (acao != null && acao.isNotEmpty) 'acao': acao,
      if (alvoTipo != null && alvoTipo.isNotEmpty) 'alvoTipo': alvoTipo,
    },
  );

  Future<Map<String, dynamic>> historicoAtendimentos({
    String? status,
    bool? finalizados,
    int? usuarioId,
  }) {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (finalizados != null) query['finalizados'] = '$finalizados';
    if (usuarioId != null) query['usuarioId'] = '$usuarioId';
    return _api.get('admin/historico/atendimentos', queryParameters: query);
  }

  Future<Map<String, dynamic>> usuarios({
    String? tipo,
    String? termo,
    String? ativo,
    int pagina = 1,
  }) => _api.get(
    'admin/usuarios',
    queryParameters: {
      'pagina': '$pagina',
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
      if (ativo != null && ativo.isNotEmpty) 'ativo': ativo,
    },
  );

  Future<Map<String, dynamic>> listarUsuarios({
    String? tipo,
    String? termo,
    bool? ativo,
    int pagina = 1,
  }) => _api.get(
    'admin/usuarios',
    queryParameters: {
      'pagina': '$pagina',
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
    String? telefone,
  }) => _api.post(
    'admin/usuarios/administradores',
    body: {
      'nome': nome,
      'email': email,
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

  Future<Map<String, dynamic>> documentos({
    String? status,
    String? tipoDocumento,
    String? termo,
    int pagina = 1,
  }) => _api.get(
    'documentos-verificacao',
    queryParameters: {
      'pagina': '$pagina',
      if (status != null && status.isNotEmpty) 'status': status,
      if (tipoDocumento != null && tipoDocumento.isNotEmpty)
        'tipoDocumento': tipoDocumento,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
    },
  );

  Future<ApiBinaryResponse> arquivoDocumento(int id) =>
      _api.getBinary('documentos-verificacao/$id/arquivo');

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

  Future<Map<String, dynamic>> denuncias({
    String? status,
    String? termo,
    int pagina = 1,
  }) => _api.get(
    'denuncias/moderacao',
    queryParameters: {
      'pagina': '$pagina',
      if (status != null && status.isNotEmpty) 'status': status,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
    },
  );

  Future<Map<String, dynamic>> moderarDenuncia(
    int id,
    String status,
    String decisao,
  ) => _api.patch(
    'denuncias/$id/moderacao',
    body: {'status': status, 'decisao': decisao},
  );

  Future<Map<String, dynamic>> avaliacoes({
    String? status,
    String? termo,
    int pagina = 1,
  }) => _api.get(
    'avaliacoes/moderacao',
    queryParameters: {
      'pagina': '$pagina',
      if (status != null && status.isNotEmpty) 'status': status,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
    },
  );

  Future<Map<String, dynamic>> moderarAvaliacao(int id, String status) =>
      _api.patch('avaliacoes/$id/moderacao', body: {'moderacaoStatus': status});

  Future<Map<String, dynamic>> categorias({
    String? ativo,
    String? termo,
    int pagina = 1,
  }) => _api.get(
    'categorias/admin',
    queryParameters: {
      'pagina': '$pagina',
      if (ativo != null && ativo.isNotEmpty) 'ativo': ativo,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
    },
  );

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
