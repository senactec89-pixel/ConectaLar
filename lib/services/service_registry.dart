import '../models/home_content.dart';
import '../models/busca_estado.dart';
import '../data/frontend_preview_client.dart';
import '../utils/constants.dart';
import 'api_mappers.dart';
import 'api_service.dart';
import 'admin_service.dart';
import 'auth_service.dart';
import 'avaliacao_service.dart';
import 'categoria_service.dart';
import 'cliente_service.dart';
import 'denuncia_service.dart';
import 'device_location_service.dart';
import 'google_identity_service.dart';
import 'historico_service.dart';
import 'mensagem_service.dart';
import 'localizacao_service.dart';
import 'notificacao_service.dart';
import 'profissional_service.dart';
import 'session_storage.dart';
import 'servico_service.dart';
import 'termos_service.dart';
import 'verificacao_service.dart';

class AppServices {
  static AppServices instance = AppServices();

  AppServices({
    ApiService? api,
    SessionStorage? sessionStorage,
    GoogleIdentityClient? googleIdentity,
    DeviceLocationClient? deviceLocation,
    this.modoDemo = AppConstants.demoMode,
    this.papelDemo = AppConstants.demoRole,
  }) : api =
           api ??
           ApiService(
             client: modoDemo ? FrontendPreviewClient(papel: papelDemo) : null,
           ) {
    this.googleIdentity = googleIdentity ?? PluginGoogleIdentityClient();
    this.deviceLocation = deviceLocation ?? GeolocatorDeviceLocationClient();
    auth = AuthService(
      this.api,
      persistirSessao: !modoDemo,
      sessionStorage: sessionStorage,
      onFederatedLogout: this.googleIdentity.signOut,
    );
    Object? usuarioBusca;
    auth.addListener(() {
      final usuario = auth.usuarioAtual?['id'];
      if (usuario != usuarioBusca || !auth.autenticado) buscaEstado.limpar();
      usuarioBusca = usuario;
    });
    this.api.onSessionExpired = auth.encerrarSessaoExpirada;
    this.api.onTermsRequired = auth.marcarTermosPendentes;
    admin = AdminService(this.api);
    avaliacoes = AvaliacaoService(this.api);
    categorias = CategoriaService(this.api);
    clientes = ClienteService(this.api);
    profissionais = ProfissionalService(this.api);
    servicos = ServicoService(this.api);
    historico = HistoricoService(this.api);
    termos = TermosService(this.api);
    notificacoes = NotificacaoService(this.api);
    mensagens = MensagemService(this.api);
    localizacao = LocalizacaoService(this.api);
    denuncias = DenunciaService(this.api);
    verificacao = VerificacaoService(this.api);
  }

  final ApiService api;
  final buscaEstado = BuscaEstado();
  final bool modoDemo;
  final String papelDemo;
  late final GoogleIdentityClient googleIdentity;
  late final DeviceLocationClient deviceLocation;
  bool get emDemonstracao => modoDemo && !auth.autenticado;
  late AuthService auth;
  late AdminService admin;
  late AvaliacaoService avaliacoes;
  late CategoriaService categorias;
  late ClienteService clientes;
  late ProfissionalService profissionais;
  late ServicoService servicos;
  late HistoricoService historico;
  late TermosService termos;
  late NotificacaoService notificacoes;
  late MensagemService mensagens;
  late LocalizacaoService localizacao;
  late DenunciaService denuncias;
  late VerificacaoService verificacao;

  Future<void> inicializar() async {
    if (modoDemo) {
      // A prévia usa somente o cliente local e não lê/altera a sessão real.
      await auth.login(email: 'previa@example.invalid', senha: 'previa-visual');
    } else {
      await auth.inicializarSessao();
    }
  }

  Future<HomeContent> carregarHome() async {
    var regionalAddressUnavailable = false;
    var nearbySearchAvailable = false;

    Future<Map<String, dynamic>?> consultarSecao(
      Future<Map<String, dynamic>> Function() consulta,
      String chave,
    ) async {
      try {
        final resposta = await consulta();
        return resposta[chave] is List ? resposta : null;
      } catch (_) {
        return null;
      }
    }

    Future<Map<String, dynamic>> listarProfissionaisDaRegiao() async {
      if (auth.usuarioAtual?['tipo'] != 'cliente') {
        return await profissionais.listar();
      }
      final response = await clientes.listarEnderecos();
      final enderecos = response['enderecos'];
      final maps = enderecos is List
          ? enderecos.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (maps.isEmpty) {
        regionalAddressUnavailable = true;
        return const {'profissionais': <dynamic>[]};
      }

      final principal = maps.firstWhere(
        (endereco) => endereco['principal'] == true,
        orElse: () => maps.first,
      );
      final latitude = doubleValueOrNull(principal['latitude']);
      final longitude = doubleValueOrNull(principal['longitude']);
      if (latitude != null && longitude != null) {
        nearbySearchAvailable = true;
        return await profissionais.buscarPorDistancia(
          latitude: latitude,
          longitude: longitude,
          raioKm: 50,
        );
      }

      String? localidade(Object? value) {
        final text = value?.toString().trim();
        return text == null || text.isEmpty ? null : text;
      }

      final bairro = localidade(principal['bairro']);
      final cidade = localidade(principal['cidade']);
      final uf = localidade(principal['uf']);
      if (bairro == null && cidade == null && uf == null) {
        regionalAddressUnavailable = true;
        return const {'profissionais': <dynamic>[]};
      }

      nearbySearchAvailable = true;
      return await profissionais.buscar(bairro: bairro, cidade: cidade, uf: uf);
    }

    final responses = await Future.wait<Map<String, dynamic>?>([
      consultarSecao(categorias.listar, 'categorias'),
      consultarSecao(listarProfissionaisDaRegiao, 'profissionais'),
    ]);
    final content = homeContentFromApi(
      categoriasResponse: responses[0] ?? const {'categorias': []},
      profissionaisResponse: responses[1] ?? const {'profissionais': []},
    );
    return HomeContent(
      categories: content.categories,
      featuredProfessionals: content.featuredProfessionals,
      featuredProfessionalsTotal: content.featuredProfessionalsTotal,
      featuredProfessionalsHasMore: content.featuredProfessionalsHasMore,
      regionalAddressUnavailable: regionalAddressUnavailable,
      nearbySearchAvailable: nearbySearchAvailable,
      categoriesLoadFailed: responses[0] == null,
      professionalsLoadFailed: responses[1] == null,
    );
  }
}
