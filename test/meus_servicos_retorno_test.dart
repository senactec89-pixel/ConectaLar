import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('meus serviços recarrega status ao retornar e preserva filtro', (
    tester,
  ) async {
    var consultas = 0;
    var concluido = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me') {
          consultas++;
          return jsonResponse({
            'solicitacoes': [
              {
                ...FrontendPreviewClient().pedidos.first,
                'status': concluido
                    ? 'conclusao_confirmada'
                    : 'aceita_agendada',
                'avaliado': concluido,
              },
            ],
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.meusServicos,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              concluido = true;
              Navigator.pop(context);
            },
            child: const Text('Retornar à lista'),
          ),
        ),
      },
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('servicos-filtro-agendados')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('servicos-filtro-agendados')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalhes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retornar à lista'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('servicos-filtro-agendados')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Ver detalhes'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('servicos-filtro-todos')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('servicos-filtro-todos')));
    await tester.pumpAndSettle();
    expect(find.text('Conclusão confirmada'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meus serviços permite retry se recarga no retorno falha', (
    tester,
  ) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me' && ++consultas == 2) {
          return jsonResponse({'message': 'Falha'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.meusServicos,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retornar à lista'),
          ),
        ),
      },
    );
    await tester.tap(find.text('Ver detalhes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retornar à lista'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(consultas, 3);
    expect(find.text('Ver detalhes'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
