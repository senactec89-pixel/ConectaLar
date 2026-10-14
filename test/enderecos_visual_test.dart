import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'endereço tem largura de leitura e ações acessíveis com texto 200%',
    (tester) async {
      await configurarFrontend();
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.enderecos,
          width: width,
          textScale: 2,
        );
        final endereco = find.text(
          'Rua de exemplo, 100 - Centro, Cidade de exemplo/MG',
        );
        expect(tester.getSize(endereco).width, greaterThan(width - 96));
        expect(tester.takeException(), isNull);
        final editar = find.widgetWithText(OutlinedButton, 'Editar');
        await tester.ensureVisible(editar);
        await tester.pumpAndSettle();
        expect(tester.getSize(editar).height, greaterThanOrEqualTo(48));
        expect(editar.hitTestable(), findsOneWidget);
        await tester.tap(editar);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Endereço fictício',
        );
        Navigator.of(tester.element(find.byType(TextFormField).first)).pop();
        await tester.pumpAndSettle();
        final remover = find.ancestor(
          of: find.text('Remover'),
          matching: find.bySubtype<TextButton>(),
        );
        await tester.ensureVisible(remover);
        await tester.pumpAndSettle();
        expect(tester.getSize(remover).height, greaterThanOrEqualTo(48));
        expect(remover.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('CEP preenche rua, bairro, cidade e UF automaticamente', (
    tester,
  ) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.enderecos);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();

    final cep = find.widgetWithText(TextFormField, 'CEP');
    await tester.enterText(cep, '01001000');
    await tester.pumpAndSettle();

    String valor(String label) => tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, label))
        .controller!
        .text;
    expect(valor('Logradouro'), 'Rua de exemplo');
    expect(valor('Bairro'), 'Centro');
    expect(valor('Cidade'), 'Cidade de exemplo');
    expect(valor('UF'), 'MG');
    expect(tester.takeException(), isNull);
  });
}
