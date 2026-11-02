import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/auth/recuperacao_senha_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/frontend_helpers.dart';

void main() {
  testWidgets('aviso de demonstração depende do código recebido da API', (
    tester,
  ) async {
    var codigoDeTeste = false;
    AppServices.instance = AppServices(
      api: ApiService(
        client: MockClient(
          (_) async => jsonResponse(
            codigoDeTeste ? {'devToken': '123456'} : {'ok': true},
          ),
        ),
      ),
    );
    addTearDown(() => AppServices.instance.api.close());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final respostaDeTeste in [false, true]) {
      codigoDeTeste = respostaDeTeste;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecuperacaoSenhaPage(key: ValueKey(respostaDeTeste)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recuperacao-email')),
        'cliente@example.invalid',
      );
      await tester.tap(find.byKey(const ValueKey('recuperacao-solicitar')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recuperacao-token')),
        '123456',
      );
      final mostrarSenha = find.byTooltip('Mostrar senha');
      await tester.ensureVisible(mostrarSenha);
      await tester.pumpAndSettle();
      await tester.tap(mostrarSenha);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Código de demonstração preenchido para este ambiente local.',
        ),
        respostaDeTeste ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('recuperação explica a senha completa com texto ampliado', (
    tester,
  ) async {
    AppServices.instance = AppServices(
      api: ApiService(
        client: MockClient((_) async => jsonResponse({'ok': true})),
      ),
    );
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
          home: RecuperacaoSenhaPage(key: ValueKey(width)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recuperacao-email')),
        'cliente@example.invalid',
      );
      final solicitar = find.byKey(const ValueKey('recuperacao-solicitar'));
      await tester.ensureVisible(solicitar);
      await tester.pumpAndSettle();
      await tester.tap(solicitar);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final orientacao = find.text(
        'Digite o código recebido. A senha deve ter pelo menos 8 caracteres, incluindo letra maiúscula, letra minúscula, número e caractere especial.',
      );
      await tester.ensureVisible(orientacao);
      await tester.pumpAndSettle();
      expect(orientacao, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(orientacao).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }
  });
}
