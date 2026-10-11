import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/service_registry.dart';

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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 44),
                const SizedBox(height: 16),
                const Text('Entre na sua conta para continuar.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.login),
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
        ),
      );
    }
    if (papeis != null &&
        !papeis!.contains(services.auth.usuarioAtual?['tipo'])) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso restrito')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Esta área não está disponível para o seu tipo de conta.',
            ),
          ),
        ),
      );
    }
    return builder(context);
  }
}
