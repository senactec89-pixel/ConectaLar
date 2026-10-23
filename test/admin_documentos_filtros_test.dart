import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('filtros equilibrados e ações com a mesma largura no mobile', (
    tester,
  ) async {
    await configurarFrontend(papel: 'administrador');
    for (final width in [360.0, 390.0, 412.0]) {
      for (final scale in [1.0, 1.4, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.adminDocumentos,
          width: width,
          textScale: scale,
        );
        final linhas = <int, int>{};
        double? larguraFiltro;
        for (final status in ['pendente', 'aprovado', 'rejeitado', '']) {
          final filtro = find.byKey(ValueKey('admin-documentos-$status'));
          final rect = tester.getRect(filtro);
          linhas.update(
            rect.top.round(),
            (total) => total + 1,
            ifAbsent: () => 1,
          );
          larguraFiltro ??= rect.width;
          expect(rect.width, closeTo(larguraFiltro, 1));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.right, lessThanOrEqualTo(width));
          final texto = find.descendant(
            of: filtro,
            matching: find.byType(Text),
          );
          expect(
            tester.renderObject<RenderParagraph>(texto).didExceedMaxLines,
            isFalse,
          );
        }
        expect(
          linhas.values.toSet().length,
          1,
          reason: 'Evitar três filtros + um.',
        );
        final visualizar = find.ancestor(
          of: find.text('Visualizar').first,
          matching: find.bySubtype<OutlinedButton>(),
        );
        final analisar = find.ancestor(
          of: find.text('Analisar').first,
          matching: find.bySubtype<FilledButton>(),
        );
        await tester.ensureVisible(analisar);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(visualizar).width,
          closeTo(tester.getSize(analisar).width, 1),
        );
        expect(tester.getSize(visualizar).height, greaterThanOrEqualTo(52));
        expect(tester.getSize(analisar).height, greaterThanOrEqualTo(52));
        expect(analisar.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$width / $scale');
      }
    }
  });

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
          final filtro = find.byKey(ValueKey('admin-documentos-${entry.key}'));
          final limites = tester.getRect(filtro);
          expect(limites.left, greaterThanOrEqualTo(0));
          expect(limites.right, lessThanOrEqualTo(width));
          expect(
            limites.bottom,
            lessThan(tester.getRect(find.byType(Scaffold)).bottom),
          );
          await tester.ensureVisible(filtro);
          await tester.pumpAndSettle();
          await tester.tap(filtro);
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

  testWidgets('rejeição mantém o motivo e permite tentar novamente', (
    tester,
  ) async {
    var envios = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/documentos-verificacao/1/arquivo') {
          return http.Response.bytes(
            '%PDF-1.4 teste'.codeUnits,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        if (request.url.path == '/documentos-verificacao/1/analisar') {
          envios++;
          expect(
            jsonDecode(request.body)['motivoRejeicao'],
            'Documento ilegível',
          );
          return envios == 1
              ? jsonResponse({'message': 'Falha temporária'}, 503)
              : jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminDocumentos);
    await tester.tap(find.text('Analisar').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Conferido'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Análise documental'), findsOneWidget);
    await tester.tap(find.text('Rejeitar'));
    await tester.pumpAndSettle();
    expect(envios, 0);
    expect(find.text('Informe o motivo para rejeitar.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Documento ilegível');
    await tester.tap(find.text('Rejeitar'));
    await tester.pumpAndSettle();
    expect(envios, 1);
    expect(find.text('Análise documental'), findsOneWidget);
    expect(find.text('Documento ilegível'), findsOneWidget);
    expect(find.textContaining('Não foi possível registrar'), findsOneWidget);
    await tester.tap(find.text('Rejeitar'));
    await tester.pumpAndSettle();
    expect(envios, 2);
    expect(find.text('Análise documental'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
