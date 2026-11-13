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

  testWidgets(
    'erro preserva ação e motivo da habilitação para nova tentativa',
    (tester) async {
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
      await tester.tap(find.text('Profissional de teste'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('habilitacao-acao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('habilitacao-acao')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspender habilitação').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('habilitacao-motivo')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('habilitacao-motivo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspeita de fraude').last);
      await tester.pumpAndSettle();

      final confirmar = find.byKey(const ValueKey('habilitacao-confirmar'));
      await tester.tap(confirmar);
      await tester.pump();
      expect(find.text('Enviando…'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
            .onPressed,
        isNull,
      );
      expect(envios, hasLength(1));

      primeiraResposta.complete(
        jsonResponse({'message': 'Falha temporária.'}, 503),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('habilitacao-erro-envio')),
        findsOneWidget,
      );
      expect(find.text('Suspender habilitação'), findsOneWidget);
      expect(find.text('Suspeita de fraude'), findsOneWidget);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(envios, [
        {'acao': 'suspender', 'motivo': 'suspeita_fraude'},
        {'acao': 'suspender', 'motivo': 'suspeita_fraude'},
      ]);
      expect(find.byKey(const ValueKey('habilitacao-confirmar')), findsNothing);
      expect(find.text('Análise registrada.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('análise de habilitação cabe com texto ampliado', (tester) async {
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
      final registro = find.text('Profissional de teste');
      await tester.scrollUntilVisible(
        registro,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(registro);
      await tester.pumpAndSettle();

      final acao = find.byKey(const ValueKey('habilitacao-acao'));
      final confirmar = find.byKey(const ValueKey('habilitacao-confirmar'));
      await tester.ensureVisible(acao);
      await tester.ensureVisible(confirmar);
      await tester.pumpAndSettle();
      expect(confirmar.hitTestable(), findsOneWidget, reason: '$width px');
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });
}
