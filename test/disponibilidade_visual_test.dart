import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('disponibilidade e formulário cabem com texto 200% e teclado', (
    tester,
  ) async {
    await configurarFrontend(papel: 'profissional');
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.disponibilidadeProfissional,
        width: width,
        textScale: 2,
      );
      expect(tester.takeException(), isNull, reason: 'Lista em $width');
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Horário'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Modal em $width');
      tester.view.physicalSize = Size(width, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Modal com teclado em $width',
      );
      final adicionar = find.ancestor(
        of: find.text('Adicionar horário'),
        matching: find.bySubtype<FilledButton>(),
      );
      await tester.ensureVisible(adicionar);
      await tester.pumpAndSettle();
      expect(adicionar.hitTestable(), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '10:00');
      await tester.enterText(fields.at(1), '12:00');
      await tester.ensureVisible(adicionar);
      await tester.pumpAndSettle();
      await tester.tap(adicionar);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      tester.view.resetViewInsets();
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('10:00 às 12:00'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('10:00 às 12:00'), findsOneWidget);
      expect(find.text('Disponibilidade salva.'), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }
  });
}
