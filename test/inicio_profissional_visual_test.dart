import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('início orienta a consultar habilitação sem presumir bloqueio', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me') {
          return jsonResponse({
            'profissional': {'verificado': true},
          });
        }
        return null;
      },
    );
    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.areaProfissional,
          width: largura,
          textScale: escala,
          overrides: {
            AppRoutes.documentosProfissional: (_) =>
                const Scaffold(body: Text('Tela de habilitação')),
          },
        );
        final aviso = find.text('Documento analisado');
        await tester.scrollUntilVisible(
          aviso,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Documento aprovado. Consulte as demais etapas de habilitação para saber se pode receber pedidos.',
          ),
          findsOneWidget,
        );
        await tester.tap(aviso);
        await tester.pumpAndSettle();
        expect(find.text('Tela de habilitação'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });
}
