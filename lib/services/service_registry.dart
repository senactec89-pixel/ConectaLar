import '../models/home_content.dart';
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
import 'historico_service.dart';
import 'mensagem_service.dart';
import 'notificacao_service.dart';
import 'profissional_service.dart';
import 'servico_service.dart';
import 'termos_service.dart';
import 'verificacao_service.dart';

class AppServices {
  static AppServices instance = AppServices();

  AppServices({
    ApiService? api,
    this.modoDemo = AppConstants.demoMode,
    this.papelDemo = AppConstants.demoRole,
  }) : api =
           api ??
           ApiService(
             client: modoDemo ? FrontendPreviewClient(papel: papelDemo) : null,
           ) {
    auth = AuthService(this.api, persistirSessao: !modoDemo);
    this.api.onSessionExpired = auth.encerrarSessaoExpirada;
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
    denuncias = DenunciaService(this.api);
    verificacao = VerificacaoService(this.api);
  }

  final ApiService api;
  final bool modoDemo;
  final String papelDemo;
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

    final responses = await Future.wait<Map<String, dynamic>?>([
      consultarSecao(categorias.listar, 'categorias'),
      consultarSecao(profissionais.listar, 'profissionais'),
    ]);
    final content = homeContentFromApi(
      categoriasResponse: responses[0] ?? const {'categorias': []},
      profissionaisResponse: responses[1] ?? const {'profissionais': []},
    );
    return HomeContent(
      categories: content.categories,
      featuredProfessionals: content.featuredProfessionals,
      categoriesLoadFailed: responses[0] == null,
      professionalsLoadFailed: responses[1] == null,
    );
  }
}
