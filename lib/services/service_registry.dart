import '../models/home_content.dart';
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

  AppServices({ApiService? api, this.modoDemo = AppConstants.demoMode})
    : api = api ?? ApiService() {
    auth = AuthService(this.api);
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

  Future<HomeContent> carregarHome() async {
    final responses = await Future.wait([
      categorias.listar(),
      profissionais.listar(),
    ]);
    return homeContentFromApi(
      categoriasResponse: responses[0],
      profissionaisResponse: responses[1],
    );
  }
}
