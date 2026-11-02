import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('admin consulta MFA ativo sem oferecer desativação', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async => request.url.path == '/auth/mfa/admin'
          ? jsonResponse({'mfaAtivo': true})
          : null,
    );
    for (final largura in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.seguranca,
        width: largura,
        textScale: 2,
      );
      await tester.scrollUntilVisible(
        find.text('Status: obrigatório e ativo'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Essa proteção não pode ser desativada'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mfa-admin-desativar-abrir')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('erro ao consultar MFA permite tentar novamente', (tester) async {
    var consultas = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/auth/mfa/admin') return null;
        return ++consultas == 1
            ? jsonResponse({'message': 'Falha'}, 503)
            : jsonResponse({'mfaAtivo': false});
      },
    );
    await abrirFrontend(tester, AppRoutes.seguranca, width: 390);
    final erro = find.text(
      'Não foi possível consultar o status do autenticador.',
    );
    await tester.scrollUntilVisible(
      erro,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final tentar = find.byTooltip('Tentar novamente');
    await tester.scrollUntilVisible(
      tentar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tentar);
    await tester.pumpAndSettle();
    expect(find.text('Status: pendente de configuração'), findsOneWidget);
    expect(
      find.textContaining('configurar o autenticador no próximo login'),
      findsOneWidget,
    );
    expect(consultas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente não recebe ações administrativas de MFA', (
    tester,
  ) async {
    await configurarFrontend(papel: 'cliente');
    await abrirFrontend(tester, AppRoutes.seguranca);
    expect(find.text('Autenticador administrativo'), findsNothing);
  });

  testWidgets('prévia administrativa mostra apenas estado demonstrativo', (
    tester,
  ) async {
    AppServices.instance = AppServices(
      modoDemo: true,
      papelDemo: 'administrador',
    );
    await AppServices.instance.inicializar();
    await abrirFrontend(tester, AppRoutes.seguranca, width: 360);
    expect(find.text('Autenticador administrativo'), findsOneWidget);
    expect(find.text('Status: pendente de configuração'), findsOneWidget);
    expect(find.byKey(const ValueKey('mfa-admin-iniciar')), findsNothing);
    expect(find.text('Conteúdo indisponível nesta prévia.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
