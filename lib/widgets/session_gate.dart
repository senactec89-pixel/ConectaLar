import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/service_registry.dart';
import 'async_state_view.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({
    required this.builder,
    this.papeis,
    this.permitirEmailNaoVerificado = false,
    this.permitirTermosPendentes = false,
    super.key,
  });

  final WidgetBuilder builder;
  final Set<String>? papeis;
  final bool permitirEmailNaoVerificado;
  final bool permitirTermosPendentes;

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
    if (!permitirEmailNaoVerificado && !services.auth.emailVerificado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirme seu e-mail')),
        body: EmptyStateView(
          title: 'Confirme seu e-mail',
          message:
              'Para proteger sua conta, confirme o código enviado por e-mail antes de continuar.',
          icon: Icons.mark_email_unread_outlined,
          action: FilledButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.verificacaoEmail,
              (_) => false,
            ),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Confirmar agora'),
          ),
        ),
      );
    }
    if (!permitirTermosPendentes && !services.auth.termosAceitos) {
      return Scaffold(
        appBar: AppBar(title: const Text('Termos atualizados')),
        body: EmptyStateView(
          title: 'Revise os termos para continuar',
          message:
              'Uma nova versao dos termos esta disponivel. Leia e confirme o aceite antes de usar as funcoes da sua conta.',
          icon: Icons.policy_outlined,
          action: FilledButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.aceiteTermos,
              (_) => false,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Ler e aceitar'),
          ),
        ),
      );
    }
    if (papeis != null &&
        !papeis!.contains(services.auth.usuarioAtual?['tipo'])) {
      final rotaDaArea = switch (services.auth.usuarioAtual?['tipo']) {
        'profissional' || 'empresa' => AppRoutes.areaProfissional,
        'administrador' => AppRoutes.admin,
        _ => AppRoutes.home,
      };
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso restrito')),
        body: EmptyStateView(
          title: 'Área indisponível para esta conta',
          message: 'Esta área não está disponível para o seu tipo de conta.',
          icon: Icons.lock_outline_rounded,
          action: FilledButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              rotaDaArea,
              (_) => false,
            ),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Ir para minha área'),
          ),
        ),
      );
    }
    return builder(context);
  }
}
