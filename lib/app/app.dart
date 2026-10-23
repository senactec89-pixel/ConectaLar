import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';
import '../services/service_registry.dart';
import '../services/auth_service.dart';
import '../widgets/demo_banner.dart';

class ConectaLarApp extends StatefulWidget {
  const ConectaLarApp({super.key});

  @override
  State<ConectaLarApp> createState() => _ConectaLarAppState();
}

class _ConectaLarAppState extends State<ConectaLarApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final AuthService _auth = AppServices.instance.auth;
  bool _loginAgendado = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_sessaoAlterada);
  }

  void _sessaoAlterada() {
    if (!_auth.sessaoExpirada || _loginAgendado) return;
    _loginAgendado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loginAgendado = false;
      if (!mounted || !_auth.sessaoExpirada) return;
      _navigator.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
      _messenger.currentState?.clearSnackBars();
      _messenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Sua sessão expirou. Entre novamente para continuar.'),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _auth.removeListener(_sessaoAlterada);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConectaLar',
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: _initialRoute(),
      routes: AppRoutes.routes,
      builder: (context, child) {
        final content = AppServices.instance.modoDemo
            ? DemoBanner(child: child!)
            : child!;
        return SafeArea(child: content);
      },
    );
  }

  String _initialRoute() {
    final auth = AppServices.instance.auth;
    if (auth.autenticado && !auth.emailVerificado) {
      return AppRoutes.verificacaoEmail;
    }
    return switch (auth.usuarioAtual?['tipo']) {
      'profissional' || 'empresa' => AppRoutes.areaProfissional,
      'administrador' => AppRoutes.admin,
      _ => AppRoutes.home,
    };
  }
}
