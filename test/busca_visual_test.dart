import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('busca mantém resultados e filtros acessíveis com texto 140%', (
    tester,
  ) async {
    await configurarFrontend();
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.busca,
        width: width,
        textScale: 1.4,
      );
      await tester.scrollUntilVisible(
        find.text('2 profissionais encontrados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull, reason: 'Resultados em $width');
      final bairro = find.byKey(const ValueKey('busca-bairro'));
      await tester.ensureVisible(bairro);
      await tester.enterText(bairro, 'Vila Nova');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Teclado em $width');
      await tester.scrollUntilVisible(
        find.text('1 profissional encontrado'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      final limpar = find.widgetWithText(TextButton, 'Limpar filtros');
      await tester.ensureVisible(limpar);
      await tester.pumpAndSettle();
      await tester.tap(limpar);
      await tester.pumpAndSettle();
      final outrasCategorias = find.widgetWithText(FilterChip, 'Outros');
      await tester.ensureVisible(outrasCategorias);
      await tester.pumpAndSettle();
      expect(outrasCategorias.hitTestable(), findsOneWidget);
      await tester.tap(outrasCategorias);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(outrasCategorias).selected, isTrue);
      await tester.scrollUntilVisible(
        find.text('Nenhum profissional encontrado.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('filtros e cabeçalho de busca vazia cabem com texto 200%', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/profissionais'
          ? jsonResponse({'profissionais': []})
          : null,
    );
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(tester, AppRoutes.busca, width: width, textScale: 2);
      await tester.scrollUntilVisible(
        find.text('0 profissionais encontrados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('0 profissionais encontrados')).width,
        lessThanOrEqualTo(width - 40),
      );
      await tester.scrollUntilVisible(
        find.text('Nenhum profissional encontrado.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
