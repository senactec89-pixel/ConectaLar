import '../models/home_content.dart';
import 'admin_service.dart';
import 'api_mappers.dart';
import 'api_service.dart';
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
  static final AppServices instance = AppServices._shared();

  AppServices._shared() : api = ApiService() {
    admin = AdminService(api);
    auth = AuthService(api);
    avaliacoes = AvaliacaoService(api);
    categorias = CategoriaService(api);
    clientes = ClienteService(api);
    profissionais = ProfissionalService(api);
    servicos = ServicoService(api);
    historico = HistoricoService(api);
    termos = TermosService(api);
    notificacoes = NotificacaoService(api);
    mensagens = MensagemService(api);
    denuncias = DenunciaService(api);
    verificacao = VerificacaoService(api);
  }

  final ApiService api;
  late AdminService admin;
  late AuthService auth;
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
