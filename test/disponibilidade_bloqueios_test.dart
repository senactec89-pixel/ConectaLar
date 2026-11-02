import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('erro de bloqueios permite tentar novamente', (tester) async {
    var consultas = 0;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/bloqueios') {
          return ++consultas == 1
              ? jsonResponse({'message': 'Falha'}, 503)
              : jsonResponse({'bloqueios': []});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.disponibilidadeProfissional);
    final tentar = find.text('Tentar carregar bloqueios novamente');
    await tester.scrollUntilVisible(
      tentar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tentar);
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.text('Nenhum período bloqueado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adicionar e remover bloqueio atualiza a lista', (tester) async {
    var bloqueado = false;
    var consultas = 0;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/bloqueios' &&
            request.method == 'GET') {
          consultas++;
          return jsonResponse({
            'bloqueios': [
              if (bloqueado)
                {
                  'id': 1,
                  'motivo': 'Compromisso',
                  'dataInicio': '2026-11-01',
                  'dataFim': '2026-11-01',
                },
            ],
          });
        }
        if (request.url.path == '/profissionais/me/bloqueios' &&
            request.method == 'POST') {
          bloqueado = true;
          return jsonResponse({'ok': true});
        }
        if (request.url.path == '/profissionais/me/bloqueios/1' &&
            request.method == 'DELETE') {
          bloqueado = false;
          return jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.disponibilidadeProfissional);
    final adicionar = find.byTooltip('Bloquear período');
    await tester.scrollUntilVisible(
      adicionar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(adicionar);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo'),
      'Compromisso',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Compromisso'), findsOneWidget);
    expect(consultas, 2);
    final remover = find.byTooltip('Remover bloqueio');
    await tester.ensureVisible(remover);
    await tester.pumpAndSettle();
    await tester.tap(remover);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum período bloqueado.'), findsOneWidget);
    expect(consultas, 3);
    expect(tester.takeException(), isNull);
  });
}
