import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('admin configura MFA e entra novamente após ativar', (
    tester,
  ) async {
    var confirmacoes = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.method == 'GET' && request.url.path == '/auth/mfa/admin') {
          return jsonResponse({'mfaAtivo': false});
        }
        if (request.method == 'POST' &&
            request.url.path == '/auth/mfa/admin/setup') {
          return jsonResponse({
            'secret': 'ABCDEF123456',
            'otpauthUrl': 'otpauth://totp/ConectaLar:admin',
          }, 201);
        }
        if (request.method == 'POST' &&
            request.url.path == '/auth/mfa/admin/confirmar') {
          confirmacoes++;
          expect(jsonDecode(request.body), {'codigo': '123456'});
          return jsonResponse({'ok': true}, 201);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.seguranca, width: 360, textScale: 2);

    final iniciar = find.byKey(const ValueKey('mfa-admin-iniciar'));
    await tester.scrollUntilVisible(
      iniciar,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(iniciar);
    await tester.pumpAndSettle();

    expect(find.text('ABCDEF123456'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('mfa-admin-codigo')),
      '123',
    );
    final confirmar = find.byKey(const ValueKey('mfa-admin-confirmar'));
    await tester.ensureVisible(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    expect(
      find.text('Digite os seis números do autenticador.'),
      findsOneWidget,
    );
    expect(confirmacoes, 0);

    await tester.enterText(
      find.byKey(const ValueKey('mfa-admin-codigo')),
      '123456',
    );
    await tester.ensureVisible(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    expect(confirmacoes, 1);
    expect(AppServices.instance.auth.autenticado, isFalse);
    expect(
      find.text('Autenticador ativado. Entre novamente com seu código.'),
      findsOneWidget,
    );
  });

  testWidgets('erro ao desativar MFA preserva senha e código', (tester) async {
    var tentativas = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.method == 'GET' && request.url.path == '/auth/mfa/admin') {
          return jsonResponse({'mfaAtivo': true});
        }
        if (request.method == 'POST' &&
            request.url.path == '/auth/mfa/admin/desativar') {
          tentativas++;
          expect(jsonDecode(request.body), {
            'senhaAtual': 'SenhaAtual123!',
            'codigo': '654321',
          });
          if (tentativas == 1) {
            return jsonResponse({'message': 'Código inválido.'}, 400);
          }
          return jsonResponse({'ok': true}, 201);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.seguranca, width: 390);

    final abrir = find.byKey(const ValueKey('mfa-admin-desativar-abrir'));
    await tester.scrollUntilVisible(
      abrir,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(abrir);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mfa-admin-senha')),
      'SenhaAtual123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mfa-admin-codigo')),
      '654321',
    );
    final desativar = find.byKey(const ValueKey('mfa-admin-desativar'));
    await tester.ensureVisible(desativar);
    await tester.pumpAndSettle();
    await tester.tap(desativar);
    await tester.pumpAndSettle();

    expect(tentativas, 1);
    expect(find.text('Código inválido.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mfa-admin-senha')))
          .controller!
          .text,
      'SenhaAtual123!',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mfa-admin-codigo')))
          .controller!
          .text,
      '654321',
    );
    await tester.ensureVisible(desativar);
    await tester.pumpAndSettle();
    await tester.tap(desativar);
    await tester.pumpAndSettle();

    expect(tentativas, 2);
    expect(AppServices.instance.auth.autenticado, isFalse);
  });

  testWidgets('cliente não recebe ações administrativas de MFA', (
    tester,
  ) async {
    await configurarFrontend(papel: 'cliente');
    await abrirFrontend(tester, AppRoutes.seguranca);
    expect(find.text('Autenticador administrativo'), findsNothing);
  });

  testWidgets('prévia admin não consulta nem altera MFA real', (tester) async {
    AppServices.instance = AppServices(
      modoDemo: true,
      papelDemo: 'administrador',
    );
    await AppServices.instance.inicializar();
    await abrirFrontend(tester, AppRoutes.seguranca, width: 360);

    expect(find.text('Autenticador administrativo'), findsOneWidget);
    expect(
      find.text(
        'Entre com uma conta administrativa na API para configurar o autenticador. A prévia não altera a segurança da conta.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mfa-admin-iniciar')), findsNothing);
    expect(find.text('Conteúdo indisponível nesta prévia.'), findsNothing);
  });
}
