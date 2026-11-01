import 'dart:convert';

import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/auth/admin_invite_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/frontend_helpers.dart';

void main() {
  testWidgets('convite explica senha e autenticador com texto ampliado', (
    tester,
  ) async {
    AppServices.instance = AppServices(modoDemo: true);
    addTearDown(() => AppServices.instance.api.close());
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final width in [360.0, 390.0, 412.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminInvitePage(key: ValueKey(width)),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final orientacao = find.text(
        'Use pelo menos 8 caracteres, com letra maiúscula, minúscula, número e caractere especial.',
      );
      await tester.scrollUntilVisible(
        orientacao,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.renderObject<RenderParagraph>(orientacao).didExceedMaxLines,
        isFalse,
      );
      final acao = find.text('Aceitar e configurar autenticador');
      await tester.scrollUntilVisible(
        acao,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(acao.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }
  });

  testWidgets('aceite do convite conduz à configuração do autenticador', (
    tester,
  ) async {
    final solicitacoes = <String>[];
    AppServices.instance = AppServices(
      api: ApiService(
        client: MockClient((request) async {
          solicitacoes.add(request.url.path);
          if (request.url.path == '/termos/atuais') {
            return jsonResponse({
              'termos': {'versao': 'teste'},
            });
          }
          if (request.url.path == '/auth/admin-convites/aceitar') {
            final dados = jsonDecode(request.body) as Map<String, dynamic>;
            expect(dados['aceitouTermos'], isTrue);
            return jsonResponse({'mfaSetupToken': 'configuracao-teste'});
          }
          if (request.url.path == '/auth/admin-mfa/setup') {
            return jsonResponse({'secret': 'CHAVEFICTICIA'});
          }
          fail('Rota inesperada: ${request.url.path}');
        }),
      ),
    );
    addTearDown(() => AppServices.instance.api.close());
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AdminInvitePage()),
    );
    await tester.pumpAndSettle();
    for (final campo in {
      'admin-convite-token': List.filled(43, 'x').join(),
      'admin-convite-senha': 'Senha123!',
      'admin-convite-confirmacao': 'Senha123!',
    }.entries) {
      final finder = find.byKey(ValueKey(campo.key));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, campo.value);
    }
    final aceite = find.byType(CheckboxListTile);
    await tester.ensureVisible(aceite);
    await tester.pumpAndSettle();
    await tester.tap(aceite);
    final acao = find.text('Aceitar e configurar autenticador');
    await tester.ensureVisible(acao);
    await tester.pumpAndSettle();
    await tester.tap(acao);
    await tester.pumpAndSettle();
    expect(find.text('Configurar autenticador'), findsOneWidget);
    expect(
      solicitacoes,
      containsAllInOrder([
        '/termos/atuais',
        '/auth/admin-convites/aceitar',
        '/auth/admin-mfa/setup',
      ]),
    );
    expect(tester.takeException(), isNull);
  });
}
