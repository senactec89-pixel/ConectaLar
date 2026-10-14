import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/api_mappers.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  Future<void> abrirFormulario(WidgetTester tester) async {
    final profissional = profissionalFromApi(
      FrontendPreviewClient().profissionais.first,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          ...AppRoutes.routes,
          AppRoutes.home: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.solicitarServico,
                arguments: profissional,
              ),
              child: const Text('Abrir formulário'),
            ),
          ),
        },
      ),
    );
    await tester.tap(find.text('Abrir formulário'));
    await tester.pumpAndSettle();
  }

  testWidgets('formulário vazio sai sem confirmação', (tester) async {
    await configurarFrontend();
    await abrirFormulario(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar solicitação?'), findsNothing);
    expect(find.text('Abrir formulário'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulário preenchido pede confirmação e preserva dados', (
    tester,
  ) async {
    await configurarFrontend();
    await abrirFormulario(tester);

    final campo = find.byKey(const ValueKey('solicitar-descricao'));
    await tester.ensureVisible(campo);
    await tester.enterText(campo, 'Instalar chuveiro no banheiro social.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar solicitação?'), findsOneWidget);

    await tester.tap(find.text('Continuar preenchendo'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar solicitação?'), findsNothing);
    expect(
      tester.widget<TextFormField>(campo).controller!.text,
      'Instalar chuveiro no banheiro social.',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir formulário'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
