import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('oferta longa e ações cabem com texto ampliado', (tester) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path != '/profissionais/me/servicos') return null;
        return jsonResponse({
          'servicos': [
            {
              'id': 7,
              'nome': 'Instalação e manutenção elétrica residencial completa',
              'categoria': {
                'id': 2,
                'nome': 'Instalações elétricas residenciais',
              },
              'precoInicial': 1200,
              'duracaoMinutos': 120,
              'intervaloMinutos': 30,
              'ativo': true,
            },
          ],
        });
      },
    );
    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.servicosProfissional,
          width: largura,
          textScale: escala,
        );
        final acao = find.byTooltip('Ações da oferta');
        await tester.scrollUntilVisible(
          acao,
          150,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(acao.hitTestable(), findsOneWidget);
        expect(find.text('A partir de R\$ 1200'), findsOneWidget);
        expect(find.text('120 min de atendimento'), findsOneWidget);
        expect(find.text('Ativa'), findsOneWidget);
        await tester.tap(acao);
        await tester.pumpAndSettle();
        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Pausar'), findsOneWidget);
        Navigator.of(tester.element(find.text('Editar'))).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });
}
