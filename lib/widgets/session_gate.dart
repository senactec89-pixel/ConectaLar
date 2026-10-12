import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/service_registry.dart';
import 'async_state_view.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({required this.builder, this.papeis, super.key});

  final WidgetBuilder builder;
  final Set<String>? papeis;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.instance;
    if (services.emDemonstracao) return builder(context);
    if (!services.auth.autenticado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sua conta')),
        body: EmptyStateView(
          title: 'Acesse sua conta',
          message: 'Entre na sua conta para continuar.',
          icon: Icons.lock_outline_rounded,
          action: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                child: const Text('Entrar'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.cadastro),
                child: const Text('Criar conta'),
              ),
            ],
          ),
        ),
      );
    }
    if (papeis != null &&
        !papeis!.contains(services.auth.usuarioAtual?['tipo'])) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso restrito')),
        body: const EmptyStateView(
          title: 'Área indisponível para esta conta',
          message: 'Esta área não está disponível para o seu tipo de conta.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }
    return builder(context);
  }
}
