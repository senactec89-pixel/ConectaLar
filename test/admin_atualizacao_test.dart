import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('painel e listas administrativas podem ser atualizados', (
    tester,
  ) async {
    final consultas = <String, int>{};
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/admin/painel' ||
            request.url.path == '/categorias/admin') {
          consultas.update(request.url.path, (v) => v + 1, ifAbsent: () => 1);
          if (request.url.path == '/categorias/admin') {
            return jsonResponse({'categorias': []});
          }
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.admin);
    final anteriorPainel = consultas['/admin/painel']!;
    await tester.tap(find.byTooltip('Atualizar painel'));
    await tester.pumpAndSettle();
    expect(consultas['/admin/painel'], anteriorPainel + 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await abrirFrontend(tester, AppRoutes.adminCategorias);
    final anteriorLista = consultas['/categorias/admin']!;
    await tester.tap(find.byTooltip('Atualizar lista'));
    await tester.pumpAndSettle();
    expect(consultas['/categorias/admin'], anteriorLista + 1);
    expect(tester.takeException(), isNull);
  });
}
