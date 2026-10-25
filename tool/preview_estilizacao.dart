// Galeria de conferência visual: usa apenas dados de demonstração.
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/admin/admin_pages.dart';
import 'package:conectarlar_app/screens/admin/categoria_form_page.dart';
import 'package:conectarlar_app/screens/admin/historico_admin_page.dart';
import 'package:conectarlar_app/screens/auth/login_page.dart';
import 'package:conectarlar_app/screens/busca/busca_page.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:conectarlar_app/screens/home/home_mock_data.dart';
import 'package:conectarlar_app/screens/notificacoes/notificacoes_page.dart';
import 'package:conectarlar_app/screens/perfil/perfil_page.dart';
import 'package:conectarlar_app/screens/perfil/seguranca_page.dart';
import 'package:conectarlar_app/screens/profissional/documentos_verificacao_page.dart';
import 'package:conectarlar_app/screens/profissional/perfil_profissional_page.dart';
import 'package:conectarlar_app/screens/profissional/area_profissional_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/utils/constants.dart';
import 'package:conectarlar_app/widgets/async_state_view.dart';
import 'package:conectarlar_app/widgets/session_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'visual_preview_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConstants.demoMode) {
    throw StateError('Esta galeria exige CONECTALAR_DEMO=true.');
  }
  final tela = Uri.base.queryParameters['tela'] ?? 'carregando';
  final escala = Uri.base.queryParameters['escala'] == '2' ? 2.0 : 1.0;
  final papel =
      tela.startsWith('admin-') || tela == 'categoria' || tela == 'historico'
      ? 'administrador'
      : tela == 'documentos' ||
            tela == 'agenda' ||
            tela == 'perfil-profissional-privado'
      ? 'profissional'
      : 'cliente';
  AppServices.instance = AppServices(
    modoDemo: true,
    papelDemo: papel,
    api: ApiService(client: VisualPreviewClient(papel: papel)),
  );
  await AppServices.instance.inicializar();
  SemanticsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      title: 'ConectaLar — prévia visual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: AppRoutes.routes,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: '/',
            arguments: tela == 'perfil-publico'
                ? HomeMockData.content.featuredProfessionals.first
                : null,
          ),
          builder: (_) => _TelaPreview(tela: tela),
        ),
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
    ),
  );
}

class _TelaPreview extends StatelessWidget {
  const _TelaPreview({required this.tela});
  final String tela;

  @override
  Widget build(BuildContext context) => switch (tela) {
    'home' => const HomePage(),
    'busca' => const BuscaPage(),
    'notificacoes' => const NotificacoesPage(),
    'perfil-publico' => const PerfilProfissionalPage(),
    'perfil-cliente' => const PerfilPage(),
    'perfil-profissional-privado' => const PerfilProfissionalPrivadoPage(),
    'agenda' => const AreaProfissionalPage(initialTab: 2),
    'categoria' => const CategoriaFormPage(),
    'historico' => const HistoricoAdminPage(),
    'admin-documentos' => const AdminPage(modulo: AdminModulo.documentos),
    'admin-denuncias' => const AdminPage(modulo: AdminModulo.denuncias),
    'admin-avaliacoes' => const AdminPage(modulo: AdminModulo.avaliacoes),
    'admin-categorias' => const AdminPage(modulo: AdminModulo.categorias),
    'login' => const LoginPage(),
    'seguranca' => const SegurancaPage(),
    'documentos' => const DocumentosVerificacaoPage(),
    'restrito' => SessionGate(
      papeis: const {'administrador'},
      builder: (_) => const Scaffold(),
    ),
    _ => Scaffold(
      appBar: AppBar(title: const Text('Prévia visual')),
      body: switch (tela) {
        'erro' => AsyncErrorView(
          message: 'Não foi possível carregar seus documentos agora.',
          onRetry: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nova tentativa acionada na prévia.')),
          ),
        ),
        'vazio' => const EmptyStateView(
          title: 'Nenhum documento pendente',
          message: 'Novos envios aparecerão nesta lista.',
          icon: Icons.verified_user_outlined,
        ),
        _ => const AsyncLoadingView(label: 'Carregando seus documentos.'),
      },
    ),
  };
}
