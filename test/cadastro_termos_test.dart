import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/services/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _abrir(WidgetTester tester, String route) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final routes = {
    ...AppRoutes.routes,
    AppRoutes.home: (_) => const Scaffold(body: Text('Home verificada')),
    AppRoutes.cadastroProfissional: (_) =>
        const Scaffold(body: Text('Próxima etapa profissional')),
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      routes: routes,
      initialRoute: route,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: route),
          builder: routes[route]!,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppServices.instance.api.close());

  testWidgets('termos são públicos, mostram versão e permitem nova tentativa', (
    tester,
  ) async {
    var tentativas = 0;
    AppServices.instance = AppServices(
      sessionStorage: MemorySessionStorage(),
      api: ApiService(
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          if (++tentativas == 1) return _json({'message': 'Falha'}, 503);
          return _json({
            'termos': {
              'versao': '2026.v1',
              'titulo': 'Termos de teste',
              'secoes': [
                {'titulo': 'Privacidade', 'texto': 'Texto retornado pela API.'},
              ],
            },
          });
        }),
      ),
    );
    await _abrir(tester, AppRoutes.termos);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Versão: 2026.v1'), findsOneWidget);
    expect(find.text('Texto retornado pela API.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro envia aceite e versao na mesma operacao atomica', (
    tester,
  ) async {
    var cadastros = 0;
    String? tipo;
    AppServices.instance = AppServices(
      sessionStorage: MemorySessionStorage(),
      api: ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/auth/cadastro') {
            cadastros++;
            final body = jsonDecode(request.body) as Map;
            tipo = body['tipo'] as String;
            expect(body['aceitouTermos'], isTrue);
            expect(body['versaoTermos'], '2026.v1');
            return _json({
              'token': {'accessToken': 'token-teste'},
              'usuario': {'id': 2, 'tipo': tipo, 'termosAceitos': true},
            });
          }
          if (request.url.path == '/termos/atuais') {
            return _json({
              'termos': {'versao': '2026.v1'},
            });
          }
          fail('Rota inesperada: ${request.url.path}');
        }),
      ),
    );
    await _abrir(tester, AppRoutes.cadastro);
    expect(find.textContaining('Passo 1 de 3'), findsNothing);
    await tester.tap(find.text('Profissional'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autônomo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empresa').last);
    await tester.pumpAndSettle();
    for (final campo in {
      'cadastro-nome': 'Empresa Teste',
      'cadastro-email': 'empresa@example.invalid',
      'cadastro-telefone': '31999990000',
      'cadastro-senha': 'Senha123!',
      'cadastro-confirmar-senha': 'Senha123!',
    }.entries) {
      await tester.enterText(find.byKey(ValueKey(campo.key)), campo.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cadastro-termos')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('cadastro-termos')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cadastro-criar-conta')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cadastro-criar-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cadastro-confirmar-email')));
    await tester.pumpAndSettle();
    expect(tipo, 'empresa');
    expect(cadastros, 1);
    expect(find.text('Próxima etapa profissional'), findsOneWidget);
    expect(cadastros, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro abre os termos antes de criar conta', (tester) async {
    var cadastros = 0;
    AppServices.instance = AppServices(
      sessionStorage: MemorySessionStorage(),
      api: ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/auth/cadastro') cadastros++;
          return _json({
            'termos': {'titulo': 'Termos de teste', 'versao': '2026.v1'},
          });
        }),
      ),
    );
    await _abrir(tester, AppRoutes.cadastro);
    await tester.scrollUntilVisible(
      find.text('Ler termos e aviso de privacidade'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ler termos e aviso de privacidade'));
    await tester.pumpAndSettle();
    expect(find.text('Termos de teste'), findsOneWidget);
    expect(cadastros, 0);
  });

  testWidgets('cadastro exige confirmacao de e-mail antes de liberar o app', (
    tester,
  ) async {
    AppServices.instance = AppServices(
      sessionStorage: MemorySessionStorage(),
      api: ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/auth/cadastro') {
            return _json({
              'token': {'accessToken': 'token-teste'},
              'usuario': {
                'id': 2,
                'nome': 'Cliente Teste',
                'email': 'cliente@example.invalid',
                'emailVerificado': false,
                'tipo': 'cliente',
                'termosAceitos': true,
              },
              'emailVerificationRequired': true,
            });
          }
          if (request.url.path == '/termos/atuais') {
            return _json({
              'termos': {'versao': '2026.v1'},
            });
          }
          expect(request.headers['authorization'], 'Bearer token-teste');
          expect(request.url.path, '/auth/email/verificacao/confirmar');
          expect(jsonDecode(request.body), {'codigo': '123456'});
          return _json({'ok': true, 'emailVerificado': true});
        }),
      ),
    );

    await _abrir(tester, AppRoutes.cadastro);
    for (final campo in {
      'cadastro-nome': 'Cliente Teste',
      'cadastro-email': 'cliente@example.invalid',
      'cadastro-telefone': '31999990001',
      'cadastro-senha': 'Senha123!',
      'cadastro-confirmar-senha': 'Senha123!',
    }.entries) {
      await tester.enterText(find.byKey(ValueKey(campo.key)), campo.value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cadastro-termos')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('cadastro-termos')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cadastro-criar-conta')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('cadastro-criar-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cadastro-confirmar-email')));
    await tester.pumpAndSettle();

    expect(find.text('Verifique sua caixa de entrada'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('email-verificacao-codigo')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('email-verificacao-confirmar')));
    await tester.pumpAndSettle();

    expect(find.text('Home verificada'), findsOneWidget);
    expect(AppServices.instance.auth.emailVerificado, isTrue);
    expect(tester.takeException(), isNull);
  });
}
