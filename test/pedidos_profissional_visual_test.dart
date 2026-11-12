import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/screens/profissional/area_profissional_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('negociacao em andamento nao mostra aceitar nem recusar', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me') {
          return jsonResponse({
            'solicitacoes': [
              {
                'id': 990,
                'status': 'aguardando_resposta',
                'negociacaoIniciada': true,
                'nomeServico': 'Montagem de cadeira',
                'cliente': {'nome': 'Cliente de teste'},
                'dataServico': '2030-04-12',
                'horarioServico': '09:00',
              },
            ],
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.areaProfissional,
      overrides: {
        AppRoutes.areaProfissional: (_) =>
            const AreaProfissionalPage(initialTab: 1),
      },
    );

    expect(find.text('Negociação em andamento'), findsOneWidget);
    expect(find.text('Continuar negociação'), findsOneWidget);
    expect(find.text('Aceitar'), findsNothing);
    expect(find.byTooltip('Recusar solicitação'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pedidos expirados ficam no histórico sem ações de decisão', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me') {
          return jsonResponse({
            'solicitacoes': [
              {
                'id': 901,
                'status': 'expirada',
                'nomeServico': 'Limpeza residencial',
                'cliente': {'nome': 'Cliente de teste'},
                'dataServico': '2030-04-12',
                'horarioServico': '09:00',
              },
              {
                'id': 902,
                'status': 'negociacao_expirada',
                'nomeServico': 'Pintura interna',
                'cliente': {'nome': 'Cliente de teste'},
                'dataServico': '2030-04-12',
                'horarioServico': '13:00',
              },
            ],
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.areaProfissional,
      overrides: {
        AppRoutes.areaProfissional: (_) =>
            const AreaProfissionalPage(initialTab: 1),
      },
    );
    final historico = find.byKey(
      const ValueKey('profissional-filtro-Histórico'),
    );
    await tester.ensureVisible(historico);
    await tester.tap(historico);
    await tester.pumpAndSettle();

    expect(find.text('Expirada'), findsOneWidget);
    expect(find.text('Negociação encerrada'), findsOneWidget);
    expect(find.text('Aceitar'), findsNothing);
    expect(find.byTooltip('Recusar solicitação'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtros de pedidos profissionais indicam que podem deslizar', (
    tester,
  ) async {
    await configurarFrontend(papel: 'profissional');
    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.areaProfissional,
          width: largura,
          textScale: escala,
          overrides: {
            AppRoutes.areaProfissional: (_) =>
                const AreaProfissionalPage(initialTab: 1),
          },
        );
        expect(find.text('Deslize para ver mais →'), findsOneWidget);
        final filtros = find.byKey(const ValueKey('profissional-filtros'));
        await tester.scrollUntilVisible(
          filtros,
          100,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final historico = find.byKey(
          const ValueKey('profissional-filtro-Histórico'),
        );
        await tester.scrollUntilVisible(
          historico,
          120,
          scrollable: find.descendant(
            of: filtros,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(historico.hitTestable(), findsOneWidget);
        await tester.tap(historico);
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(historico).selected, isTrue);
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });
}
