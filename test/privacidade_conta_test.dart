import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('seguranca explica exportacao e exige confirmacao forte', (
    tester,
  ) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.seguranca, width: 360, textScale: 2);

    expect(find.text('Exportar meus dados'), findsOneWidget);
    expect(find.text('Excluir minha conta'), findsOneWidget);

    final acaoExcluir = find.byKey(const ValueKey('seguranca-excluir-conta'));
    await tester.scrollUntilVisible(
      acaoExcluir,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(acaoExcluir);
    await tester.pumpAndSettle();

    expect(find.text('Excluir conta permanentemente?'), findsOneWidget);
    final excluir = find.widgetWithText(
      FilledButton,
      'Excluir definitivamente',
    );
    expect(tester.widget<FilledButton>(excluir).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('exclusao-senha-atual')),
      'SenhaAtual123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exclusao-confirmacao')),
      'excluir',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(excluir).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('exclusao-confirmacao')),
      'EXCLUIR',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(excluir).onPressed, isNotNull);
  });

  testWidgets('exclusao confirmada limpa a sessao local', (tester) async {
    var exclusaoRecebida = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/privacidade/me/exclusao') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['senhaAtual'], 'SenhaAtual123!');
          expect(body['confirmacao'], 'EXCLUIR');
          exclusaoRecebida = true;
          return jsonResponse({
            'ok': true,
            'contaExcluida': true,
            'message': 'Conta excluida.',
          }, 201);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.seguranca);

    final acaoExcluir = find.byKey(const ValueKey('seguranca-excluir-conta'));
    await tester.scrollUntilVisible(
      acaoExcluir,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(acaoExcluir);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exclusao-senha-atual')),
      'SenhaAtual123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exclusao-confirmacao')),
      'EXCLUIR',
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Excluir definitivamente'),
    );
    await tester.pumpAndSettle();

    expect(exclusaoRecebida, isTrue);
    expect(AppServices.instance.auth.autenticado, isFalse);
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('administrador pode exportar mas nao se autoexcluir', (
    tester,
  ) async {
    await configurarFrontend(papel: 'administrador');
    await abrirFrontend(tester, AppRoutes.seguranca);

    expect(find.text('Exportar meus dados'), findsOneWidget);
    expect(find.text('Conta administrativa'), findsOneWidget);
    expect(find.text('Excluir minha conta'), findsNothing);
  });

  test('senha incorreta na exportacao nao encerra a sessao', () async {
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/privacidade/me/exportacao') {
          return jsonResponse({
            'code': 'SENHA_ATUAL_INVALIDA',
            'message': 'Senha atual incorreta.',
          }, 401);
        }
        return null;
      },
    );

    await expectLater(
      AppServices.instance.auth.exportarDados(senhaAtual: 'SenhaIncorreta123!'),
      throwsException,
    );
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(AppServices.instance.auth.sessaoExpirada, isFalse);
  });
}
