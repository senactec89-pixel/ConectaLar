import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/app.dart';
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/frontend_helpers.dart';

void main() {
  const sessionKey = 'conectalar.auth.session.v1';
  tearDown(() => AppServices.instance.api.close());

  testWidgets('sessao salva sem e-mail verificado abre confirmacao de e-mail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      sessionKey: jsonEncode({
        'accessToken': 'token-nao-verificado',
        'usuario': {
          'id': 77,
          'nome': 'Conta sem verificacao',
          'email': 'sem-verificacao@example.invalid',
          'tipo': 'cliente',
          'emailVerificado': false,
        },
      }),
    });
    AppServices.instance = AppServices(
      modoDemo: false,
      api: ApiService(client: MockClient((request) async => jsonResponse({}))),
    );
    await AppServices.instance.inicializar();

    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    expect(find.text('Verifique sua caixa de entrada'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('email-verificacao-codigo')),
      findsOneWidget,
    );
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(AppServices.instance.auth.emailVerificado, isFalse);
  });

  testWidgets('area privada bloqueia conta autenticada sem e-mail verificado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      sessionKey: jsonEncode({
        'accessToken': 'token-nao-verificado',
        'usuario': {
          'id': 78,
          'nome': 'Conta sem verificacao',
          'email': 'sem-verificacao2@example.invalid',
          'tipo': 'cliente',
          'emailVerificado': false,
        },
      }),
    });
    AppServices.instance = AppServices(
      modoDemo: false,
      api: ApiService(client: MockClient((request) async => jsonResponse({}))),
    );
    await AppServices.instance.inicializar();

    await abrirFrontend(tester, AppRoutes.favoritos);

    expect(find.text('Confirme seu e-mail'), findsWidgets);
    expect(find.text('Confirmar agora'), findsOneWidget);
  });

  testWidgets(
    '401 autenticado limpa sessão e leva ao login sem retorno à tela privada',
    (tester) async {
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/notificacoes/me') {
            return jsonResponse({'message': 'Expirou'}, 401);
          }
          return null;
        },
      );
      await tester.pumpWidget(const ConectaLarApp());
      await tester.pumpAndSettle();
      await expectLater(
        AppServices.instance.notificacoes.listar(),
        throwsA(isA<ApiException>()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
      expect(
        find.text('Sua sessão expirou. Entre novamente para continuar.'),
        findsOneWidget,
      );
      expect(AppServices.instance.auth.autenticado, isFalse);
      expect(AppServices.instance.auth.usuarioAtual, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(sessionKey),
        isNull,
      );
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('erro de credenciais e 403 não encerram sessão por expiração', () async {
    var negarLogin = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/auth/login' && negarLogin) {
          return jsonResponse({'message': 'Credenciais inválidas'}, 401);
        }
        if (request.url.path == '/admin/usuarios') {
          return jsonResponse({'message': 'Sem permissão'}, 403);
        }
        return null;
      },
    );
    negarLogin = true;
    await expectLater(
      AppServices.instance.auth.login(
        email: 'invalido@example.invalid',
        senha: 'invalida',
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      AppServices.instance.admin.usuarios(),
      throwsA(isA<ApiException>()),
    );
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(AppServices.instance.auth.sessaoExpirada, isFalse);
  });

  test('resposta 401 antiga não apaga uma sessão nova', () async {
    var logins = 0;
    final respostaAntiga = Completer<http.Response>();
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/auth/login') {
          return jsonResponse({
            'token': {'accessToken': 'token-teste-${++logins}'},
            'usuario': {'id': logins, 'tipo': 'cliente'},
          });
        }
        if (request.url.path == '/notificacoes/me') {
          return respostaAntiga.future;
        }
        return null;
      },
    );
    final pendente = AppServices.instance.notificacoes.listar();
    final expectativa = expectLater(pendente, throwsA(isA<ApiException>()));
    await AppServices.instance.auth.login(
      email: 'novo@example.invalid',
      senha: 'teste',
    );
    respostaAntiga.complete(jsonResponse({'message': 'Expirou'}, 401));
    await expectativa;
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(AppServices.instance.auth.usuarioAtual?['id'], 2);
    final saved =
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(sessionKey)!,
            )
            as Map;
    expect(saved['usuario']['id'], 2);
  });

  test(
    '401 simultâneos encerram uma vez, inclusive com resposta não JSON',
    () async {
      final respostas = [
        Completer<http.Response>(),
        Completer<http.Response>(),
      ];
      var consultas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/notificacoes/me') {
            return respostas[consultas++].future;
          }
          return null;
        },
      );
      var expiracoes = 0;
      AppServices.instance.auth.addListener(() {
        if (AppServices.instance.auth.sessaoExpirada) expiracoes++;
      });
      final primeira = expectLater(
        AppServices.instance.notificacoes.listar(),
        throwsA(isA<ApiException>()),
      );
      final segunda = expectLater(
        AppServices.instance.notificacoes.listar(),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      respostas[0].complete(http.Response('Unauthorized', 401));
      respostas[1].complete(jsonResponse({'message': 'Expirou'}, 401));
      await Future.wait([primeira, segunda]);
      expect(expiracoes, 1);
      expect(AppServices.instance.auth.autenticado, isFalse);
    },
  );
}
