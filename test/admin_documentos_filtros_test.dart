import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'filtros documentais consultam status existente e cabem nas três larguras',
    (tester) async {
      final consultas = <String?>[];
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path == '/documentos-verificacao') {
            consultas.add(request.url.queryParameters['status']);
          }
          return null;
        },
      );
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.adminDocumentos,
          width: width,
          textScale: 1.4,
        );
        expect(consultas.last, 'pendente');
        expect(find.textContaining('documento-ficticio-1.pdf'), findsOneWidget);
        for (final entry in {'aprovado': 2, 'rejeitado': 3, '': 0}.entries) {
          await tester.ensureVisible(
            find.byKey(ValueKey('admin-documentos-${entry.key}')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(ValueKey('admin-documentos-${entry.key}')),
          );
          await tester.pumpAndSettle();
          expect(consultas.last, entry.key.isEmpty ? null : entry.key);
          if (entry.value > 0) {
            expect(
              find.textContaining('documento-ficticio-${entry.value}.pdf'),
              findsOneWidget,
            );
            expect(
              find.textContaining('documento-ficticio-1.pdf'),
              findsNothing,
            );
          } else {
            expect(
              find.textContaining('documento-ficticio-1.pdf'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('erro e lista vazia preservam o filtro documental escolhido', (
    tester,
  ) async {
    var aprovados = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/documentos-verificacao' &&
            request.url.queryParameters['status'] == 'aprovado') {
          if (++aprovados == 1) return jsonResponse({'message': 'Falha'}, 503);
          return jsonResponse({'documentos': []});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminDocumentos);
    await tester.tap(find.byKey(const ValueKey('admin-documentos-aprovado')));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('admin-documentos-aprovado')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(aprovados, 2);
    expect(find.text('Nenhum documento neste filtro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visualizacao documental usa rota privada antes da analise', (
    tester,
  ) async {
    var carregamentos = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/documentos-verificacao/1/arquivo') {
          carregamentos++;
          expect(request.headers['authorization'], startsWith('Bearer '));
          return http.Response.bytes(
            '%PDF-1.4 teste'.codeUnits,
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition':
                  'inline; filename="documento-ficticio-1.pdf"',
            },
          );
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.adminDocumentos);
    await tester.tap(find.byTooltip('Visualizar arquivo').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(carregamentos, 1);
    expect(find.text('Arquivo do documento'), findsOneWidget);
    expect(find.text('documento-ficticio-1.pdf'), findsWidgets);
    expect(find.textContaining('application/pdf'), findsOneWidget);

    await tester.tap(find.text('Conferido'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('Arquivo carregado para conferência'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
