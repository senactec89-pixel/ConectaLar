import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

const _submit = ValueKey('admin-criar-salvar');

Future<void> _fillForm(WidgetTester tester) async {
  for (final entry in {
    'nome': 'Ana Administradora',
    'email': 'ana@example.invalid',
    'telefone': '(31) 99999-4321',
  }.entries) {
    final field = find.byKey(ValueKey('admin-criar-${entry.key}'));
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
  }
  await tester.ensureVisible(find.byKey(_submit));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('sends an admin invitation without changing current session', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    String? authorization;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/admin/usuarios/administradores') {
          return null;
        }
        expect(request.method, 'POST');
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        authorization = request.headers['Authorization'];
        return jsonResponse({
          'usuario': {'id': 999, 'nome': 'Ana Administradora'},
          'convite': {'emailEnviado': true, 'estado': 'enviado'},
        }, 201);
      },
    );
    final currentUser = Map<String, dynamic>.from(
      AppServices.instance.auth.usuarioAtual!,
    );
    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: AppRoutes.routes,
        initialRoute: '/test',
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.pushNamed(
                    context,
                    AppRoutes.adminCriarAdministrador,
                  );
                },
                child: const Text('Open invitation'),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Open invitation'));
    await tester.pumpAndSettle();
    await _fillForm(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(payload, {
      'nome': 'Ana Administradora',
      'email': 'ana@example.invalid',
      'telefone': '(31) 99999-4321',
    });
    expect(authorization, startsWith('Bearer '));
    expect(result, {'criado': true, 'emailEnviado': true});
    expect(AppServices.instance.auth.usuarioAtual, currentUser);
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps form values and shows API error for retry', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async =>
          request.url.path == '/admin/usuarios/administradores'
          ? jsonResponse({'message': 'Falha'}, 503)
          : null,
    );
    await abrirFrontend(tester, AppRoutes.adminCriarAdministrador);
    await _fillForm(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-criar-erro')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('admin-criar-email')),
          )
          .controller!
          .text,
      'ana@example.invalid',
    );
    expect(
      tester.widget<FilledButton>(find.byKey(_submit)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('prevents duplicate submits while invitation is pending', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var calls = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/admin/usuarios/administradores') {
          return null;
        }
        calls++;
        return response.future;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminCriarAdministrador);
    await _fillForm(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Enviando convite...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_submit)).onPressed, isNull);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    await tester.tap(find.byKey(_submit));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);

    response.complete(jsonResponse({'message': 'Tente novamente.'}, 503));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(_submit)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid email does not call admin endpoint', (tester) async {
    var calls = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/admin/usuarios/administradores') calls++;
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminCriarAdministrador);
    final email = find.byKey(const ValueKey('admin-criar-email'));
    await tester.enterText(email, 'invalid');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
