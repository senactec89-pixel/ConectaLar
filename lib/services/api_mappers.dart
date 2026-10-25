import '../data/conectalar_mock_store.dart';
import '../utils/constants.dart';
import '../models/categoria.dart';
import '../models/cliente_endereco.dart';
import '../models/disponibilidade.dart';
import '../models/documento_verificacao.dart';
import '../models/home_content.dart';
import '../models/mensagem.dart';
import '../models/notificacao.dart';
import '../models/profissional.dart';
import '../models/solicitacao.dart';
import '../models/usuario.dart';

HomeContent homeContentFromApi({
  required Map<String, dynamic> categoriasResponse,
  required Map<String, dynamic> profissionaisResponse,
}) {
  return HomeContent(
    categories: listFromApi(categoriasResponse['categorias'], categoriaFromApi),
    featuredProfessionals: listFromApi(
      profissionaisResponse['profissionais'],
      profissionalFromApi,
    ),
    featuredProfessionalsTotal:
        _nonNegativeInt(
          (profissionaisResponse['paginacao'] as Map?)?['total'],
        ) ??
        (profissionaisResponse['profissionais'] is List
            ? (profissionaisResponse['profissionais'] as List).length
            : 0),
    featuredProfessionalsHasMore:
        ((profissionaisResponse['paginacao'] as Map?)?['temMais'] == true),
  );
}

int? _nonNegativeInt(Object? value) {
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : null;
}

Categoria categoriaFromApi(Map<String, dynamic> json) {
  return Categoria(
    id: intValue(json['id']),
    nome: stringValue(json['nome']),
    icone: nullableString(json['icone']) ?? 'home_repair',
    ativa: boolValue(json['ativo'], fallback: true),
  );
}

Profissional profissionalFromApi(Map<String, dynamic> json) {
  final servicosRaw = json['servicos'];
  final servicos = servicosRaw is List
      ? servicosRaw
            .whereType<Map<String, dynamic>>()
            .map((servico) => stringValue(servico['nome']))
            .where((nome) => nome.isNotEmpty)
            .toList(growable: false)
      : const <String>[];
  final categoriaIds = servicosRaw is List
      ? servicosRaw
            .whereType<Map<String, dynamic>>()
            .map((servico) => intValue(servico['categoria']?['id']))
            .where((id) => id > 0)
            .toSet()
            .toList(growable: false)
      : const <int>[];

  return Profissional(
    id: intValue(json['id']),
    usuarioId: intValue(json['usuarioId']),
    nome: stringValue(json['nome']),
    descricao: stringValue(json['descricao']),
    bairro: stringValue(json['bairro']),
    cidade: nullableString(json['cidade']),
    uf: nullableString(json['uf']),
    raioAtendimentoKm: json['raioAtendimentoKm'] == null
        ? 15
        : intValue(json['raioAtendimentoKm']),
    latitudeAproximada: doubleValueOrNull(json['latitudeAproximada']),
    longitudeAproximada: doubleValueOrNull(json['longitudeAproximada']),
    distanciaKm: doubleValueOrNull(json['distanciaKm']),
    precoInicial: doubleValueOrNull(json['precoInicial']),
    categoriaIds: categoriaIds,
    verificado: boolValue(json['verificado']),
    podeReceberSolicitacoes: json['podeReceberSolicitacoes'] == true,
    habilitacaoInformada: json['podeReceberSolicitacoes'] is bool,
    fotoUrl: apiUrlOrNull(json['fotoPerfilUrl']),
    servicos: servicos,
    ofertas: listFromApi(
      json['servicos'],
      (s) => OfertaProfissional(
        id: intValue(s['id']),
        nome: stringValue(s['nome']),
        categoriaId: s['categoria']?['id'] == null
            ? null
            : intValue(s['categoria']?['id']),
        precoInicial: doubleValueOrNull(s['precoInicial']),
        duracaoMinutos: s['duracaoMinutos'] == null
            ? 60
            : intValue(s['duracaoMinutos']),
        intervaloMinutos: s['intervaloMinutos'] == null
            ? 30
            : intValue(s['intervaloMinutos']),
      ),
    ),
    notaMedia: doubleValueOrNull(json['notaMedia']),
    quantidadeAvaliacoes: intValue(json['quantidadeAvaliacoes']),
  );
}

Solicitacao solicitacaoFromApi(Map<String, dynamic> json) {
  final profissional = json['profissional'];
  final categoria = json['categoria'];

  return Solicitacao(
    id: intValue(json['id']),
    clienteId: intValue(json['cliente']?['id']),
    profissionalId: profissional is Map<String, dynamic>
        ? intValue(profissional['id'])
        : 0,
    profissionalUsuarioId: intValue(profissional?['usuarioId']),
    servicoId: json['servicoId'] == null ? null : intValue(json['servicoId']),
    nomeServico: nullableString(json['nomeServico']),
    categoriaId: categoria is Map<String, dynamic>
        ? intValue(categoria['id'])
        : 0,
    enderecoId: json['enderecoId'] == null
        ? null
        : intValue(json['enderecoId']),
    descricao: stringValue(json['descricao']),
    bairroAtendimento: stringValue(json['bairroAtendimento']),
    enderecoProtegido: boolValue(json['enderecoProtegido']),
    enderecoCompletoLiberado: boolValue(json['enderecoCompletoLiberado']),
    enderecoAtendimento: json['enderecoAtendimento'] is Map<String, dynamic>
        ? clienteEnderecoFromApi(
            json['enderecoAtendimento'] as Map<String, dynamic>,
          )
        : null,
    dataServico: dateValue(json['dataServico']),
    horarioServico: stringValue(json['horarioServico']),
    duracaoMinutos: json['duracaoMinutos'] == null
        ? 60
        : intValue(json['duracaoMinutos']),
    intervaloMinutos: json['intervaloMinutos'] == null
        ? 30
        : intValue(json['intervaloMinutos']),
    reagendamento: json['reagendamento'] is Map<String, dynamic>
        ? json['reagendamento'] as Map<String, dynamic>
        : null,
    reagendamentos: (json['reagendamentos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false),
    orcamento: json['orcamento'] is Map<String, dynamic>
        ? json['orcamento'] as Map<String, dynamic>
        : null,
    orcamentos: (json['orcamentos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false),
    cancelamentoMotivo: nullableString(json['cancelamentoMotivo']),
    conclusaoContestacaoMotivo: nullableString(
      json['conclusaoContestacaoMotivo'],
    ),
    naoComparecimentoMotivo: nullableString(json['naoComparecimentoMotivo']),
    naoComparecimentoPorId: json['naoComparecimentoPorId'] == null
        ? null
        : intValue(json['naoComparecimentoPorId']),
    eventos: (json['eventos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false),
    precoInicial: doubleValueOrNull(json['precoInicial']),
    precoFinal: doubleValueOrNull(json['precoFinal']),
    status: statusSolicitacaoFromApi(stringValue(json['status'])),
    criadoEm: dateTimeValue(json['criadoEm']),
    atualizadoEm: dateTimeValue(json['atualizadoEm']),
  );
}

AtendimentoResumo atendimentoResumoFromApi(Map<String, dynamic> json) {
  final profissional = json['profissional'];
  final cliente = json['cliente'];
  final categoria = json['categoria'];
  return AtendimentoResumo(
    profissional: profissional is Map<String, dynamic>
        ? stringValue(profissional['nome'])
        : 'Profissional',
    cliente: cliente is Map<String, dynamic>
        ? nullableString(cliente['nome'])
        : null,
    categoria:
        nullableString(json['nomeServico']) ??
        (categoria is Map<String, dynamic>
            ? stringValue(categoria['nome'])
            : 'Serviço'),
    solicitacao: solicitacaoFromApi(json),
    avaliado: boolValue(json['avaliado']),
  );
}

Mensagem mensagemFromApi(Map<String, dynamic> json) {
  final autor = json['autor'];
  return Mensagem(
    id: intValue(json['id']),
    solicitacaoId: intValue(json['solicitacaoId']),
    remetenteId: autor is Map<String, dynamic> ? intValue(autor['id']) : 0,
    conteudo: stringValue(json['conteudo']),
    lida: boolValue(json['lida'], fallback: true),
    criadoEm: dateTimeValue(json['criadoEm']),
  );
}

Usuario usuarioFromApi(Map<String, dynamic> json) {
  return Usuario(
    id: intValue(json['id']),
    nome: stringValue(json['nome']),
    email: stringValue(json['email']),
    tipo: tipoUsuarioFromApi(stringValue(json['tipo'])),
    telefone: nullableString(json['telefone']),
    bairro: nullableString(json['bairroPrincipal'] ?? json['bairro']),
    fotoPerfilUrl: apiUrlOrNull(json['fotoPerfilUrl']),
  );
}

ClienteEndereco clienteEnderecoFromApi(Map<String, dynamic> json) {
  return ClienteEndereco(
    id: intValue(json['id']),
    apelido: stringValue(json['apelido']),
    cep: nullableString(json['cep']),
    latitude: doubleValueOrNull(json['latitude']),
    longitude: doubleValueOrNull(json['longitude']),
    logradouro: stringValue(json['logradouro']),
    numero: stringValue(json['numero']),
    complemento: nullableString(json['complemento']),
    bairro: stringValue(json['bairro']),
    cidade: stringValue(json['cidade']),
    uf: stringValue(json['uf']),
    principal: boolValue(json['principal']),
  );
}

Disponibilidade disponibilidadeFromApi(Map<String, dynamic> json) {
  return Disponibilidade(
    id: intValue(json['id']),
    diaSemana: intValue(json['diaSemana']),
    horaInicio: stringValue(json['horaInicio']),
    horaFim: stringValue(json['horaFim']),
    ativo: boolValue(json['ativo'], fallback: true),
  );
}

Notificacao notificacaoFromApi(Map<String, dynamic> json) {
  return Notificacao(
    id: intValue(json['id']),
    tipo: stringValue(json['tipo']),
    titulo: stringValue(json['titulo']),
    mensagem: stringValue(json['mensagem']),
    recursoTipo: nullableString(json['recursoTipo']),
    recursoId: json['recursoId'] == null ? null : intValue(json['recursoId']),
    lida: boolValue(json['lida']),
    lidaEm: json['lidaEm'] == null ? null : dateTimeValue(json['lidaEm']),
    criadoEm: dateTimeValue(json['criadoEm']),
  );
}

DocumentoVerificacao documentoVerificacaoFromApi(Map<String, dynamic> json) {
  return DocumentoVerificacao(
    id: intValue(json['id']),
    tipoDocumento: stringValue(json['tipoDocumento']),
    referenciaArquivo: stringValue(json['referenciaArquivo']),
    nomeArquivo: nullableString(json['nomeArquivo']),
    observacao: nullableString(json['observacao']),
    status: stringValue(json['status']),
    motivoRejeicao: nullableString(json['motivoRejeicao']),
    analisadoEm: json['analisadoEm'] == null
        ? null
        : dateTimeValue(json['analisadoEm']),
    criadoEm: dateTimeValue(json['criadoEm']),
  );
}

StatusSolicitacao statusSolicitacaoFromApi(String value) {
  return StatusSolicitacao.values.firstWhere(
    (status) => status.valorBanco == value,
    orElse: () => StatusSolicitacao.aguardandoResposta,
  );
}

TipoUsuario tipoUsuarioFromApi(String value) {
  return TipoUsuario.values.firstWhere(
    (tipo) => tipo.valorBanco == value,
    orElse: () => TipoUsuario.cliente,
  );
}

List<T> listFromApi<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(mapper)
      .toList(growable: false);
}

int intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? doubleValueOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool boolValue(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

String stringValue(Object? value) => value?.toString() ?? '';

String? nullableString(Object? value) {
  final text = stringValue(value).trim();
  return text.isEmpty ? null : text;
}

String? apiUrlOrNull(Object? value) {
  final path = nullableString(value);
  if (path == null) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final baseUrl = AppConstants.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
  return '$baseUrl/$normalizedPath';
}

DateTime dateValue(Object? value) {
  final text = stringValue(value);
  return DateTime.tryParse(text) ?? DateTime.now();
}

DateTime dateTimeValue(Object? value) {
  final text = stringValue(value);
  return DateTime.tryParse(text) ?? DateTime.now();
}
