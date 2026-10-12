// Galeria de conferência visual: usa apenas dados de demonstração.
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/auth/login_page.dart';
import 'package:conectarlar_app/screens/perfil/seguranca_page.dart';
import 'package:conectarlar_app/screens/profissional/documentos_verificacao_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/utils/constants.dart';
import 'package:conectarlar_app/widgets/async_state_view.dart';
import 'package:conectarlar_app/widgets/demo_banner.dart';
import 'package:conectarlar_app/widgets/session_gate.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConstants.demoMode) {
    throw StateError('Esta galeria exige CONECTALAR_DEMO=true.');
  }
  final tela = Uri.base.queryParameters['tela'] ?? 'carregando';
  AppServices.instance = AppServices(
    modoDemo: true,
    papelDemo: tela == 'documentos' ? 'profissional' : 'cliente',
  );
  await AppServices.instance.inicializar();
  runApp(
    MaterialApp(
      title: 'ConectaLar — prévia visual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: AppRoutes.routes,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => _TelaPreview(tela: tela),
        ),
      ],
      builder: (context, child) => DemoBanner(child: child!),
    ),
  );
}

class _TelaPreview extends StatelessWidget {
  const _TelaPreview({required this.tela});
  final String tela;

  @override
  Widget build(BuildContext context) => switch (tela) {
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
