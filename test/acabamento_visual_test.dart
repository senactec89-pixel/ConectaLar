import 'dart:convert';
import 'dart:io';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/widgets/async_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  for (final route in [
    AppRoutes.areaProfissional,
    AppRoutes.detalhesSolicitacaoProfissional,
    AppRoutes.perfilProfissionalPrivado,
    AppRoutes.servicosProfissional,
    AppRoutes.disponibilidadeProfissional,
    AppRoutes.documentosProfissional,
    AppRoutes.cadastroProfissional,
    AppRoutes.avaliacoesRecebidas,
  ]) {
    testWidgets(
      'tela profissional $route preenchida e ampliada nas três larguras',
      (tester) async {
        await configurarFrontend(papel: 'profissional');
        for (final width in [360.0, 390.0, 412.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await abrirFrontend(
            tester,
            route,
            arguments: 1002,
            width: width,
            textScale: 2,
          );
          expect(find.text('Tentar novamente'), findsNothing);
          expect(find.text('Acesso restrito'), findsNothing);
          expect(tester.takeException(), isNull, reason: '$route em $width');
          if (route == AppRoutes.areaProfissional) {
            await tester.tap(find.text('Agenda').last);
            await tester.pumpAndSettle();
            expect(find.text('Tentar novamente'), findsNothing);
            expect(tester.takeException(), isNull, reason: 'Agenda em $width');
            await tester.tap(find.text('Pedidos').last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Pedidos em $width');
          }
          if (route == AppRoutes.cadastroProfissional) {
            await tester.scrollUntilVisible(
              find.text('Descrição profissional'),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            final campo = find.byType(TextField).first;
            await tester.ensureVisible(campo);
            await tester.pumpAndSettle();
            await tester.tap(campo);
            await tester.pump();
            expect(
              tester
                  .widget<EditableText>(
                    find.descendant(
                      of: campo,
                      matching: find.byType(EditableText),
                    ),
                  )
                  .focusNode
                  .hasFocus,
              isTrue,
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Cadastro com teclado em $width',
            );
            FocusManager.instance.primaryFocus?.unfocus();
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
          }
        }
        addTearDown(tester.view.resetViewInsets);
      },
    );
  }

  testWidgets('login começa vazio e cabe ampliado com teclado aberto', (
    tester,
  ) async {
    await configurarFrontend();
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(tester, AppRoutes.login, width: width, textScale: 2);
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('login-email')),
      );
      expect(field.controller!.text, isEmpty);
      await tester.tap(find.byKey(const ValueKey('login-email')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
    }
    addTearDown(tester.view.resetViewInsets);
  });

  testWidgets('edição de empresa cabe ampliada nas três larguras', (
    tester,
  ) async {
    await configurarFrontend(papel: 'empresa');
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.cadastroProfissional,
        width: width,
        textScale: 2,
      );
      expect(AppServices.instance.auth.usuarioAtual?['tipo'], 'empresa');
      expect(find.text('Tentar novamente'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('estados vazios e erros têm scroll quando a altura é pequena', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 220);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final estado in [
      AsyncErrorView(
        message: 'Não foi possível carregar este conteúdo. Tente novamente.',
        onRetry: () {},
      ),
      const EmptyStateView(
        title: 'Nenhum resultado encontrado',
        message: 'Escolha outro filtro ou aguarde novos registros.',
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: estado),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('identidade web usa nome idioma descrição e cores do aplicativo', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
    final html = File('web/index.html').readAsStringSync();
    expect(manifest['name'], 'ConectaLar');
    expect(manifest['short_name'], 'ConectaLar');
    expect(manifest['theme_color'], '#157A54');
    expect(manifest['background_color'], '#F6FAF7');
    expect(manifest['description'], contains('serviços residenciais'));
    expect(html, contains('<html lang="pt-BR">'));
    expect(html, contains('<title>ConectaLar</title>'));
    expect(html, isNot(contains('A new Flutter project')));
  });
}
