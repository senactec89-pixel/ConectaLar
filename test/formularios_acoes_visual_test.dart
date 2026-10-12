import 'dart:async';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/auth/login_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('validação de senha permanece inteira com texto 200% e teclado', (
    tester,
  ) async {
    await configurarFrontend();
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.seguranca,
        width: width,
        textScale: 2,
      );
      final campos = find.byType(TextFormField);
      for (var index = 0; index < 3; index++) {
        await tester.ensureVisible(campos.at(index));
        await tester.enterText(
          campos.at(index),
          index == 0 ? 'Senha123!' : 'abcdefgh',
        );
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final salvar = find.byKey(const ValueKey('seguranca-salvar'));
      await tester.ensureVisible(salvar);
      await tester.pumpAndSettle();
      expect(tester.getSize(salvar).height, greaterThanOrEqualTo(52));
      await tester.tap(salvar);
      await tester.pumpAndSettle();
      final erros = find.text(
        'Use maiuscula, minuscula, numero e caractere especial.',
      );
      expect(erros, findsNWidgets(2));
      for (final element in erros.evaluate()) {
        expect(
          (element.renderObject! as RenderParagraph).didExceedMaxLines,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }
  });

  testWidgets('login em envio bloqueia repetição e preserva dados após erro', (
    tester,
  ) async {
    final resposta = Completer<http.Response>();
    var chamadas = 0;
    AppServices.instance = AppServices(
      api: ApiService(
        client: MockClient((request) {
          chamadas++;
          return resposta.future;
        }),
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginPage()),
    );
    await tester.pumpAndSettle();
    final email = find.byKey(const ValueKey('login-email'));
    final senha = find.byKey(const ValueKey('login-senha'));
    await tester.ensureVisible(email);
    await tester.enterText(email, 'teste@example.invalid');
    await tester.ensureVisible(senha);
    await tester.enterText(senha, 'Senha123!');
    final entrar = find.byKey(const ValueKey('login-entrar'));
    await tester.ensureVisible(entrar);
    await tester.pumpAndSettle();
    await tester.tap(entrar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Entrando...'), findsOneWidget);
    expect(tester.widget<FilledButton>(entrar).onPressed, isNull);
    expect(tester.widget<TextFormField>(email).enabled, isFalse);
    expect(tester.widget<TextFormField>(senha).enabled, isFalse);
    await tester.tap(entrar);
    await tester.pump(const Duration(milliseconds: 100));
    expect(chamadas, 1);
    resposta.complete(
      jsonResponse({'message': 'Confira seus dados de acesso.'}, 400),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(email).enabled, isTrue);
    expect(
      tester.widget<TextFormField>(email).controller!.text,
      'teste@example.invalid',
    );
    expect(tester.widget<TextFormField>(senha).controller!.text, 'Senha123!');
    expect(tester.widget<FilledButton>(entrar).onPressed, isNotNull);
    expect(find.text('Confira seus dados de acesso.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor de documento conserva valores com texto ampliado', (
    tester,
  ) async {
    await configurarFrontend(papel: 'profissional');
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.documentosProfissional,
        width: width,
        textScale: 2,
      );
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Enviar'));
      await tester.pumpAndSettle();
      final tipo = find.byType(DropdownButtonFormField<String>);
      expect(find.text('Identificação'), findsOneWidget);
      await tester.tap(tipo);
      await tester.pumpAndSettle();
      final endereco = find.text('Comprovante de endereço').last;
      await tester.ensureVisible(endereco);
      await tester.pumpAndSettle();
      await tester.tap(endereco);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DropdownButtonFormField<String>>(tipo).initialValue,
        'comprovante_endereco',
      );
      final selecionar = find.widgetWithText(
        OutlinedButton,
        'Selecionar arquivo',
      );
      await tester.ensureVisible(selecionar);
      await tester.pumpAndSettle();
      expect(tester.getSize(selecionar).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }
  });
}
