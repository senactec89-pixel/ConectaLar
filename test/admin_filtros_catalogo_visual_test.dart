import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'filtros do catálogo indicam rolagem e permitem selecionar inativas',
    (tester) async {
      final consultas = <Uri>[];
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path != '/categorias/admin') return null;
          consultas.add(request.url);
          return jsonResponse({
            'categorias': [
              {'id': 7, 'nome': 'Categoria de exemplo', 'ativo': false},
            ],
          });
        },
      );
      for (final largura in [360.0, 390.0, 412.0]) {
        for (final escala in [1.0, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await abrirFrontend(
            tester,
            AppRoutes.adminCategorias,
            width: largura,
            textScale: escala,
          );
          expect(find.text('Deslize para ver mais filtros →'), findsOneWidget);
          final lista = find.byType(ListView).first;
          final filtros = find.byKey(
            const ValueKey('admin-categorias-filtros'),
          );
          await tester.scrollUntilVisible(
            filtros,
            100,
            scrollable: find
                .descendant(of: lista, matching: find.byType(Scrollable))
                .first,
          );
          final inativas = find.byKey(
            const ValueKey('admin-categorias-inativa'),
          );
          await tester.scrollUntilVisible(
            inativas,
            100,
            scrollable: find.descendant(
              of: filtros,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(inativas);
          await tester.pumpAndSettle();
          expect(consultas.last.queryParameters['ativo'], 'false');
          expect(tester.widget<ChoiceChip>(inativas).selected, isTrue);
          expect(
            tester.takeException(),
            isNull,
            reason: '$largura px, $escala×',
          );
        }
      }
    },
  );
}
