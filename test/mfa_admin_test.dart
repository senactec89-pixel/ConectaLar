import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'admin sees mandatory MFA status without unsafe self-service toggles',
    (tester) async {
      var statusQueries = 0;
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.method == 'GET' &&
              request.url.path == '/auth/mfa/admin') {
            statusQueries++;
            return jsonResponse({'mfaAtivo': true});
          }
          return null;
        },
      );
      await abrirFrontend(
        tester,
        AppRoutes.seguranca,
        width: 360,
        textScale: 2,
      );

      await tester.scrollUntilVisible(
        find.text('Autenticador administrativo'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Status: obrigatório e ativo'), findsOneWidget);
      expect(statusQueries, 1);
      expect(find.byKey(const ValueKey('mfa-admin-iniciar')), findsNothing);
      expect(find.byKey(const ValueKey('mfa-admin-desativar')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MFA pendente e explicado como bloqueio aplicado pela API', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async => request.url.path == '/auth/mfa/admin'
          ? jsonResponse({'mfaAtivo': false})
          : null,
    );
    await abrirFrontend(tester, AppRoutes.seguranca);
    await tester.scrollUntilVisible(
      find.text('Autenticador administrativo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Status: pendente de configuração'), findsOneWidget);
    expect(
      find.textContaining('O acesso administrativo ficará disponível'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mfa-admin-iniciar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente nao recebe o estado administrativo de MFA', (
    tester,
  ) async {
    await configurarFrontend(papel: 'cliente');
    await abrirFrontend(tester, AppRoutes.seguranca);
    expect(find.text('Autenticador administrativo'), findsNothing);
  });

  testWidgets('falha ao consultar MFA oferece nova tentativa', (tester) async {
    var consultas = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/auth/mfa/admin') return null;
        if (++consultas == 1) return jsonResponse({'message': 'Falha'}, 503);
        return jsonResponse({'mfaAtivo': true});
      },
    );
    await abrirFrontend(tester, AppRoutes.seguranca);
    await tester.scrollUntilVisible(
      find.text('Autenticador administrativo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final retry = find.byTooltip('Tentar novamente');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    expect(retry.hitTestable(), findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(consultas, 2);
    expect(find.text('Status: obrigatório e ativo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo nao chama a API para consultar ou alterar MFA', (
    tester,
  ) async {
    AppServices.instance = AppServices(
      modoDemo: true,
      papelDemo: 'administrador',
    );
    await AppServices.instance.inicializar();
    await abrirFrontend(tester, AppRoutes.seguranca, width: 360);
    await tester.scrollUntilVisible(
      find.text('Autenticador administrativo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Status: pendente de configuração'), findsOneWidget);
    expect(
      find.textContaining('O acesso administrativo ficará disponível'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mfa-admin-iniciar')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
