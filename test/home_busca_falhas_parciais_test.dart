import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('Home mantém profissionais se categorias falharem e recupera', (
    tester,
  ) async {
    var falharCategorias = true;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/categorias' && falharCategorias) {
          return jsonResponse({'message': 'Falha temporária'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.home);

    expect(
      find.text('Não foi possível carregar as categorias.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Carlos Silva — demonstração'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Carlos Silva — demonstração'), findsOneWidget);

    falharCategorias = false;
    await tester.scrollUntilVisible(
      find.text('Tentar novamente'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as categorias.'), findsNothing);
    expect(find.text('Elétrica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Busca mantém categorias se profissionais falharem e recupera', (
    tester,
  ) async {
    var falharProfissionais = true;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/profissionais' && falharProfissionais) {
          return jsonResponse({'message': 'Falha temporária'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.busca);

    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Elétrica'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Não foi possível carregar os profissionais.'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Não foi possível carregar os profissionais.'),
      findsOneWidget,
    );

    falharProfissionais = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os profissionais.'),
      findsNothing,
    );
    expect(find.text('2 profissionais encontrados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
