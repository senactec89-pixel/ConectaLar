import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

const _salvar = ValueKey('admin-criar-salvar');

Future<void> _preencher(WidgetTester tester) async {
  for (final campo in {
    'nome': '  Ana Administradora  ',
    'email': 'ana@example.invalid',
    'telefone': '(31) 99999-4321',
    'senha': 'Segura123!',
    'confirmacao': 'Segura123!',
  }.entries) {
    final field = find.byKey(ValueKey('admin-criar-${campo.key}'));
    await tester.ensureVisible(field);
    await tester.enterText(field, campo.value);
  }
  await tester.ensureVisible(find.byKey(_salvar));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('cria administrador com contrato existente sem trocar sessão', (
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
          'usuario': {
            'id': 999,
            'nome': 'Ana Administradora',
            'tipo': 'administrador',
          },
        }, 201);
      },
    );
    final usuarioAnterior = Map<String, dynamic>.from(
      AppServices.instance.auth.usuarioAtual!,
    );
    Object? resultado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: AppRoutes.routes,
        initialRoute: '/teste',
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  resultado = await Navigator.pushNamed(
                    context,
                    AppRoutes.adminCriarAdministrador,
                  );
                },
                child: const Text('Abrir cadastro'),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Abrir cadastro'));
    await tester.pumpAndSettle();
    await _preencher(tester);
    await tester.tap(find.byKey(_salvar));
    await tester.pumpAndSettle();
    expect(payload, {
      'nome': 'Ana Administradora',
      'email': 'ana@example.invalid',
      'telefone': '(31) 99999-4321',
      'senha': 'Segura123!',
    });
    expect(authorization, startsWith('Bearer '));
    expect(resultado, isTrue);
    expect(find.text('Abrir cadastro'), findsOneWidget);
    expect(AppServices.instance.auth.usuarioAtual, usuarioAnterior);
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final status in [409, 403]) {
    testWidgets('erro $status mantém os dados e permite nova tentativa', (
      tester,
    ) async {
      var chamadas = 0;
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path != '/admin/usuarios/administradores') {
            return null;
          }
          chamadas++;
          return jsonResponse({'message': 'Falha'}, status);
        },
      );
      await abrirFrontend(tester, AppRoutes.adminCriarAdministrador);
      await _preencher(tester);
      await tester.tap(find.byKey(_salvar));
      await tester.pumpAndSettle();
      expect(chamadas, 1);
      expect(
        find.text(
          status == 409
              ? 'Não foi possível criar a conta com estes dados. Confira o e-mail e o telefone.'
              : 'Sua conta não tem permissão para criar administradores.',
        ),
        findsOneWidget,
      );
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
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('admin-criar-senha')),
            )
            .controller!
            .text,
        'Segura123!',
      );
      expect(
        tester.widget<FilledButton>(find.byKey(_salvar)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('envio bloqueia repetição, campos e saída enquanto aguarda', (
    tester,
  ) async {
    final resposta = Completer<http.Response>();
    var chamadas = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/admin/usuarios/administradores') {
          return null;
        }
        chamadas++;
        return resposta.future;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminCriarAdministrador);
    await _preencher(tester);
    await tester.tap(find.byKey(_salvar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Criando conta...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_salvar)).onPressed, isNull);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    expect(
      tester.widget<PopScope>(find.byType(PopScope).first).canPop,
      isFalse,
    );
    await tester.tap(find.byKey(_salvar));
    await tester.pump(const Duration(milliseconds: 100));
    expect(chamadas, 1);
    resposta.complete(jsonResponse({'message': 'Tente novamente.'}, 503));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(_salvar)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'conta cliente não acessa cadastro nem envia chamada administrativa',
    (tester) async {
      var chamadas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/admin/usuarios/administradores') {
            chamadas++;
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.adminCriarAdministrador);
      expect(find.text('Área indisponível para esta conta'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(chamadas, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cadastro e validações cabem em 360, 390 e 412 com texto 200% e teclado',
    (tester) async {
      var chamadas = 0;
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path == '/admin/usuarios/administradores') {
            chamadas++;
          }
          return null;
        },
      );
      addTearDown(tester.view.resetViewInsets);
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.adminCriarAdministrador,
          width: width,
          textScale: 2,
        );
        final senha = find.byKey(const ValueKey('admin-criar-senha'));
        await tester.ensureVisible(senha);
        await tester.enterText(senha, 'fraca');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(_salvar));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(_salvar)).height,
          greaterThanOrEqualTo(52),
        );
        await tester.tap(find.byKey(_salvar));
        await tester.pumpAndSettle();
        expect(
          find.text('Informe um nome entre 3 e 140 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text('A senha deve ter pelo menos 8 caracteres.'),
          findsOneWidget,
        );
        expect(find.text('As senhas precisam ser iguais.'), findsOneWidget);
        expect(chamadas, 0);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      }
    },
  );
}
