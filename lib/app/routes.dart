import 'package:flutter/material.dart';

import '../widgets/session_gate.dart';

import '../screens/auth/cadastro_page.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/termos_page.dart';
import '../screens/auth/verificacao_email_page.dart';
import '../screens/admin/admin_pages.dart';
import '../screens/admin/criar_administrador_page.dart';
import '../screens/admin/historico_admin_page.dart';
import '../screens/busca/busca_page.dart';
import '../screens/chat/chat_page.dart';
import '../screens/chat/conversa_page.dart';
import '../screens/favoritos/favoritos_page.dart';
import '../screens/home/home_page.dart';
import '../screens/notificacoes/notificacoes_page.dart';
import '../screens/perfil/enderecos_page.dart';
import '../screens/perfil/editar_dados_page.dart';
import '../screens/perfil/denuncias_page.dart';
import '../screens/perfil/perfil_page.dart';
import '../screens/perfil/seguranca_page.dart';
import '../screens/auth/recuperacao_senha_page.dart';
import '../screens/profissional/cadastro_profissional_page.dart';
import '../screens/profissional/disponibilidade_page.dart';
import '../screens/profissional/documentos_verificacao_page.dart';
import '../screens/admin/habilitacoes_page.dart';
import '../screens/profissional/perfil_profissional_page.dart';
import '../screens/profissional/area_profissional_page.dart';
import '../screens/profissional/avaliacoes_recebidas_page.dart';
import '../screens/servicos/detalhes_servico_page.dart';
import '../screens/servicos/denunciar_servico_page.dart';
import '../screens/servicos/meus_servicos_page.dart';
import '../screens/servicos/solicitar_servico_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const cadastro = '/cadastro';
  static const termos = '/termos';
  static const busca = '/busca';
  static const resultados = '/busca/resultados';
  static const perfilProfissional = '/profissionais/perfil';
  static const cadastroProfissional = '/profissionais/cadastro';
  static const meusServicos = '/servicos';
  static const solicitarServico = '/servicos/solicitar';
  static const detalhesServico = '/servicos/detalhes';
  static const denunciarServico = '/servicos/denunciar';
  static const favoritos = '/favoritos';
  static const chat = '/chat';
  static const conversa = '/chat/conversa';
  static const perfil = '/perfil';
  static const enderecos = '/perfil/enderecos';
  static const editarDados = '/perfil/dados';
  static const minhasDenuncias = '/perfil/denuncias';
  static const seguranca = '/perfil/seguranca';
  static const privacidade = '/perfil/privacidade';
  static const recuperacaoSenha = '/senha/recuperacao';
  static const verificacaoEmail = '/email/verificacao';
  static const notificacoes = '/notificacoes';
  static const disponibilidadeProfissional = '/profissionais/disponibilidade';
  static const documentosProfissional = '/profissionais/documentos';
  static const areaProfissional = '/profissionais/inicio';
  static const detalhesSolicitacaoProfissional =
      '/profissionais/solicitacoes/detalhes';
  static const servicosProfissional = '/profissionais/servicos';
  static const perfilProfissionalPrivado = '/profissionais/meu-perfil';
  static const avaliacoesRecebidas = '/profissionais/avaliacoes';
  static const admin = '/admin';
  static const adminUsuarios = '/admin/usuarios';
  static const adminCriarAdministrador = '/admin/usuarios/novo-administrador';
  static const adminHistorico = '/admin/historico';
  static const adminDocumentos = '/admin/documentos';
  static const adminHabilitacoes = '/admin/habilitacoes';
  static const adminDenuncias = '/admin/denuncias';
  static const adminAvaliacoes = '/admin/avaliacoes';
  static const adminCategorias = '/admin/categorias';
  static const adminAuditoria = '/admin/auditoria';

  static final Map<String, WidgetBuilder> _builders = {
    home: (_) => const HomePage(),
    login: (_) => const LoginPage(),
    cadastro: (_) => const CadastroPage(),
    termos: (_) => const TermosPage(),
    busca: (_) => const BuscaPage(),
    resultados: (_) => const BuscaPage(),
    perfilProfissional: (_) => const PerfilProfissionalPage(),
    cadastroProfissional: (_) => const CadastroProfissionalPage(),
    meusServicos: (_) => const MeusServicosPage(),
    solicitarServico: (_) => const SolicitarServicoPage(),
    detalhesServico: (_) => const DetalhesServicoPage(),
    denunciarServico: (_) => const DenunciarServicoPage(),
    favoritos: (_) => const FavoritosPage(),
    chat: (_) => const ChatPage(),
    conversa: (_) => const ConversaPage(),
    perfil: (_) => const PerfilPage(),
    enderecos: (_) => const EnderecosPage(),
    editarDados: (_) => const EditarDadosPage(),
    minhasDenuncias: (_) => const DenunciasPage(),
    seguranca: (_) => const SegurancaPage(),
    privacidade: (_) => const SegurancaPage(mostrarPrivacidade: true),
    recuperacaoSenha: (_) => const RecuperacaoSenhaPage(),
    verificacaoEmail: (_) => const VerificacaoEmailPage(),
    notificacoes: (_) => const NotificacoesPage(),
    disponibilidadeProfissional: (_) => const DisponibilidadePage(),
    documentosProfissional: (_) => const DocumentosVerificacaoPage(),
    areaProfissional: (context) {
      final initialTab = ModalRoute.of(context)?.settings.arguments;
      return AreaProfissionalPage(
        initialTab: initialTab is int && initialTab >= 0 && initialTab <= 2
            ? initialTab
            : 0,
      );
    },
    detalhesSolicitacaoProfissional: (_) => const DetalhesServicoPage(),
    servicosProfissional: (_) => const ServicosProfissionalPage(),
    perfilProfissionalPrivado: (_) => const PerfilProfissionalPrivadoPage(),
    avaliacoesRecebidas: (_) => const AvaliacoesRecebidasPage(),
    admin: (_) => const AdminPage(),
    adminUsuarios: (_) => const AdminPage(modulo: AdminModulo.usuarios),
    adminCriarAdministrador: (_) => const CriarAdministradorPage(),
    adminHistorico: (_) => const HistoricoAdminPage(),
    adminDocumentos: (_) => const AdminPage(modulo: AdminModulo.documentos),
    adminHabilitacoes: (_) => const HabilitacoesPage(),
    adminDenuncias: (_) => const AdminPage(modulo: AdminModulo.denuncias),
    adminAvaliacoes: (_) => const AdminPage(modulo: AdminModulo.avaliacoes),
    adminCategorias: (_) => const AdminPage(modulo: AdminModulo.categorias),
    adminAuditoria: (_) => const AdminPage(modulo: AdminModulo.auditoria),
  };
  static Map<String, WidgetBuilder> get routes =>
      _builders.map((route, builder) {
        const publicas = {
          home,
          login,
          cadastro,
          termos,
          busca,
          resultados,
          perfilProfissional,
          recuperacaoSenha,
        };
        if (publicas.contains(route)) return MapEntry(route, builder);
        if (route == verificacaoEmail ||
            route == seguranca ||
            route == privacidade) {
          return MapEntry(
            route,
            (context) =>
                SessionGate(builder: builder, permitirEmailNaoVerificado: true),
          );
        }
        final Set<String>? papeis = route.startsWith('/admin')
            ? {'administrador'}
            : route.startsWith('/profissionais/')
            ? {'profissional', 'empresa'}
            : route == editarDados
            ? {'cliente', 'profissional', 'empresa', 'administrador'}
            : {favoritos, solicitarServico, enderecos}.contains(route)
            ? {'cliente'}
            : null;
        return MapEntry(
          route,
          (context) => SessionGate(builder: builder, papeis: papeis),
        );
      });
}
