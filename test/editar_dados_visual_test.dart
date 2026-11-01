import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/screens/perfil/editar_dados_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('perfil confirma ao retornar após salvar dados', (tester) async {
    var salvamentos = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.method == 'PUT' && request.url.path == '/clientes/me') {
          salvamentos++;
          return jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.perfil);
    await tester.tap(find.text('Meus dados'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('perfil-email')),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('perfil-nome')),
      'Maria Silva',
    );
    final salvar = find.byKey(const ValueKey('perfil-salvar'));
    await tester.ensureVisible(salvar);
    await tester.pumpAndSettle();
    await tester.tap(salvar);
    await tester.pumpAndSettle();
    expect(salvamentos, 1);
    expect(find.text('Dados salvos com sucesso.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Meus dados mostra a ajuda inteira com texto 200% e teclado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    AppServices.instance = AppServices(modoDemo: true);

    for (final largura in [360.0, 390.0, 412.0]) {
      tester.view.physicalSize = Size(largura, 844);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(largura),
          theme: AppTheme.light,
          home: const EditarDadosPage(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$largura px');

      final ajuda = find.text(
        'E-mail vinculado à conta. A alteração não está disponível nesta tela.',
      );
      await tester.scrollUntilVisible(
        ajuda,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.renderObject<RenderParagraph>(ajuda).didExceedMaxLines,
        isFalse,
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('perfil-salvar')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$largura px com teclado');
      tester.view.resetViewInsets();
    }
  });

  testWidgets('erro de Meus dados mantém nova tentativa em altura reduzida', (
    tester,
  ) async {
    AppServices.instance = AppServices(modoDemo: false);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 220);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const EditarDadosPage(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithText(OutlinedButton, 'Tentar novamente'))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
