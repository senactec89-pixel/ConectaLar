import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());
  for (final caso in [
    ('cliente', AppRoutes.editarDados),
    ('profissional', AppRoutes.cadastroProfissional),
  ]) {
    testWidgets('${caso.$1}: voltar preserva ou descarta alterações', (
      tester,
    ) async {
      await configurarFrontend(papel: caso.$1);
      await abrirFrontend(
        tester,
        AppRoutes.home,
        width: 360,
        textScale: 2,
        overrides: {
          AppRoutes.home: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.pushNamed(context, caso.$2),
              child: const Text('Abrir formulário'),
            ),
          ),
        },
      );
      await tester.tap(find.text('Abrir formulário'));
      await tester.pumpAndSettle();
      final campo = caso.$1 == 'profissional'
          ? find.widgetWithText(TextFormField, 'Descrição profissional')
          : find.byType(TextFormField).first;
      await tester.scrollUntilVisible(
        campo,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(campo, 'Alteração ainda não salva');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(campo).controller!.text,
        'Alteração ainda não salva',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir formulário'), findsOneWidget);
      await tester.tap(find.text('Abrir formulário'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('Abrir formulário'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
