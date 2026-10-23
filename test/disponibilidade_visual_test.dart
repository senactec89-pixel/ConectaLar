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
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async =>
          request.url.path.endsWith('/disponibilidade')
          ? jsonResponse({'disponibilidades': []})
          : null,
    );
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
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Adicionar horário').first,
      );
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

  testWidgets('atalhos de dias úteis e fim de semana preenchem vários dias', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async =>
          request.url.path.endsWith('/disponibilidade')
          ? jsonResponse({'disponibilidades': []})
          : null,
    );
    await abrirFrontend(tester, AppRoutes.disponibilidadeProfissional);
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Adicionar horário').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dias úteis'));
    await tester.pumpAndSettle();
    expect(find.text('Segunda a sexta-feira'), findsOneWidget);
    final adicionar = find.ancestor(
      of: find.text('Adicionar horário'),
      matching: find.bySubtype<FilledButton>(),
    );
    await tester.tap(adicionar);
    await tester.pumpAndSettle();
    expect(find.text('Segunda-feira'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sexta-feira'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sexta-feira'), findsOneWidget);
    expect(find.text('09:00 às 18:00'), findsNWidgets(5));

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Adicionar horário').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fim de semana'));
    await tester.pumpAndSettle();
    expect(find.text('Sábado e domingo'), findsOneWidget);
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), '19:00');
    await tester.enterText(campos.at(1), '20:00');
    await tester.tap(adicionar);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sábado'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sábado'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Domingo'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Domingo'), findsOneWidget);
    expect(find.text('19:00 às 20:00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('personalizado valida dias sem fechar o formulário', (
    tester,
  ) async {
    await configurarFrontend(papel: 'profissional');
    await abrirFrontend(tester, AppRoutes.disponibilidadeProfissional);
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Adicionar horário').first,
    );
    await tester.pumpAndSettle();
    final segunda = find.widgetWithText(FilterChip, 'Segunda-feira');
    await tester.tap(segunda);
    await tester.pumpAndSettle();
    final adicionar = find.ancestor(
      of: find.text('Adicionar horário'),
      matching: find.bySubtype<FilledButton>(),
    );
    await tester.tap(adicionar);
    await tester.pumpAndSettle();
    expect(find.text('Selecione pelo menos um dia da semana.'), findsOneWidget);
    expect(adicionar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
