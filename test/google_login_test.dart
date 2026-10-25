import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/auth/login_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/google_identity_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/services/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeGoogleIdentity implements GoogleIdentityClient {
  final _tokens = StreamController<String>.broadcast();
  int signOutCalls = 0;

  @override
  bool get configured => true;

  @override
  Stream<String> get idTokens => _tokens.stream;

  @override
  bool get supportsAuthenticate => true;

  @override
  Future<String> authenticate() async => 'google-id-token';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _session(String tipo, {bool contaCriada = false}) => {
  'contaCriada': contaCriada,
  'usuario': {
    'id': 41,
    'nome': 'Pessoa Google',
    'email': 'pessoa@gmail.com',
    'emailVerificado': true,
    'tipo': tipo,
    'googleVinculado': true,
  },
  'token': {
    'accessToken': 'token-conectalar',
    'tokenType': 'Bearer',
    'expiresIn': 3600,
  },
};

Future<void> _openLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.home: (_) => const Scaffold(body: Text('Home autenticada')),
        AppRoutes.cadastroProfissional: (_) =>
            const Scaffold(body: Text('Cadastro profissional')),
        AppRoutes.termos: (_) => const Scaffold(body: Text('Termos')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Google login sends only ID token and opens existing client home',
    (tester) async {
      final google = _FakeGoogleIdentity();
      Map<String, dynamic>? requestBody;
      AppServices.instance = AppServices(
        sessionStorage: MemorySessionStorage(),
        googleIdentity: google,
        api: ApiService(
          client: MockClient((request) async {
            requestBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(_session('cliente'));
          }),
        ),
      );

      await _openLogin(tester);
      final button = find.byKey(const ValueKey('login-google'));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Home autenticada'), findsOneWidget);
      expect(requestBody, {'idToken': 'google-id-token'});
      expect(AppServices.instance.auth.usuarioAtual?['googleVinculado'], true);
    },
  );

  testWidgets('new Google professional accepts terms before account creation', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    var call = 0;
    AppServices.instance = AppServices(
      sessionStorage: MemorySessionStorage(),
      googleIdentity: _FakeGoogleIdentity(),
      api: ApiService(
        client: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/termos/atuais')) {
            return _json({
              'termos': {'versao': '2026.v1'},
            });
          }
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          call++;
          if (call == 1) {
            return _json({
              'cadastroNecessario': true,
              'perfilGoogle': {
                'nome': 'Nova Profissional',
                'email': 'nova@gmail.com',
              },
            });
          }
          return _json(_session('profissional', contaCriada: true));
        }),
      ),
    );

    await _openLogin(tester);
    final googleButton = find.byKey(const ValueKey('login-google'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(googleButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Concluir cadastro'), findsOneWidget);
    await tester.tap(find.text('Profissional'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('google-cadastro-senha')),
      'SenhaGoogle123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('google-cadastro-confirmar-senha')),
      'SenhaGoogle123!',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 200));
    final terms = find.byKey(const ValueKey('google-cadastro-termos'));
    await tester.ensureVisible(terms);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(terms);
    await tester.tap(find.byKey(const ValueKey('google-cadastro-continuar')));
    await tester.pumpAndSettle();

    expect(find.text('Cadastro profissional'), findsOneWidget);
    expect(requests, [
      {'idToken': 'google-id-token'},
      {
        'idToken': 'google-id-token',
        'tipo': 'profissional',
        'senha': 'SenhaGoogle123!',
        'aceitouTermos': true,
        'versaoTermos': '2026.v1',
      },
    ]);
  });
}
