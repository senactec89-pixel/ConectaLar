import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('habilitacao permite nova tentativa depois de falha', (
    tester,
  ) async {
    final primeiraResposta = Completer<http.Response>();
    final envios = <Map<String, dynamic>>[];
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/admin/profissionais/habilitacoes') {
          return jsonResponse({
            'pagina': 1,
            'total': 1,
            'profissionais': [
              {
                'id': 10,
                'nome': 'Profissional de teste',
                'habilitacao': {
                  'estado': 'pendente',
                  'podeAtender': false,
                  'etapas': [],
                },
              },
            ],
          });
        }
        if (request.url.path == '/admin/profissionais/10/habilitacao') {
          envios.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (envios.length == 1) return primeiraResposta.future;
          return jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminHabilitacoes, width: 360);

    Future<void> selecionarSuspensao() async {
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      final dialogo = find.byType(Dialog).last;
      final scrollable = find
          .descendant(of: dialogo, matching: find.byType(Scrollable))
          .first;
      final campos = find.descendant(
        of: dialogo,
        matching: find.byType(DropdownButtonFormField<String>),
      );
      final acao = campos.first;
      await tester.scrollUntilVisible(acao, 100, scrollable: scrollable);
      await tester.tap(acao);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Suspender').last);
      await tester.pumpAndSettle();
      final motivo = campos.last;
      await tester.scrollUntilVisible(motivo, 100, scrollable: scrollable);
      await tester.tap(motivo);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('fraude').last);
      await tester.pumpAndSettle();
      final confirmar = find.widgetWithText(FilledButton, 'Confirmar');
      await tester.scrollUntilVisible(confirmar, 100, scrollable: scrollable);
      await tester.tap(confirmar);
    }

    await selecionarSuspensao();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(envios, hasLength(1));

    primeiraResposta.complete(
      jsonResponse({'message': 'Temporary failure.'}, 503),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await selecionarSuspensao();
    await tester.pumpAndSettle();
    expect(envios, [
      {'acao': 'suspender', 'motivo': 'suspeita_fraude'},
      {'acao': 'suspender', 'motivo': 'suspeita_fraude'},
    ]);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialogo de habilitacao cabe com texto ampliado', (tester) async {
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async =>
          request.url.path == '/admin/profissionais/habilitacoes'
          ? jsonResponse({
              'pagina': 1,
              'total': 1,
              'profissionais': [
                {
                  'id': 10,
                  'nome': 'Profissional de teste',
                  'habilitacao': {
                    'estado': 'pendente',
                    'podeAtender': false,
                    'etapas': [],
                  },
                },
              ],
            })
          : null,
    );

    for (final width in [320.0, 360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.adminHabilitacoes,
        width: width,
        textScale: 2,
      );
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      final dialogo = find.byType(Dialog).last;
      final scrollable = find
          .descendant(of: dialogo, matching: find.byType(Scrollable))
          .first;
      final campos = find.descendant(
        of: dialogo,
        matching: find.byType(DropdownButtonFormField<String>),
      );
      final acao = campos.first;
      final confirmar = find.widgetWithText(FilledButton, 'Confirmar');
      await tester.scrollUntilVisible(acao, 100, scrollable: scrollable);
      await tester.scrollUntilVisible(confirmar, 100, scrollable: scrollable);
      expect(confirmar.hitTestable(), findsOneWidget, reason: '$width px');
      expect(tester.takeException(), isNull, reason: '$width px');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    }
  });
}
