import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('filtros de avaliações indicam rolagem e alcançam uma estrela', (
    tester,
  ) async {
    final consultas = <Uri>[];
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path != '/profissionais/me/avaliacoes') return null;
        consultas.add(request.url);
        return jsonResponse({'avaliacoes': [], 'resumo': {}});
      },
    );
    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.avaliacoesRecebidas,
          width: largura,
          textScale: escala,
        );
        expect(find.text('Deslize para ver mais →'), findsOneWidget);
        final filtros = find.byKey(const ValueKey('avaliacoes-filtros-nota'));
        await tester.ensureVisible(filtros);
        await tester.pumpAndSettle();
        final umaEstrela = find.byKey(const ValueKey('avaliacoes-nota-1'));
        await tester.scrollUntilVisible(
          umaEstrela,
          120,
          scrollable: find.descendant(
            of: filtros,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(umaEstrela);
        await tester.pumpAndSettle();
        expect(consultas.last.queryParameters['nota'], '1');
        expect(
          find.text('Nenhuma avaliação com estes filtros'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });
}
