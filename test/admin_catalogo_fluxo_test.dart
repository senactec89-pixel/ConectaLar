import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'catálogo filtra, limpa busca e volta da edição com lista atualizada',
    (tester) async {
      final categorias = <Map<String, dynamic>>[
        {'id': 1, 'nome': 'Pintura', 'icone': 'format_paint', 'ativo': true},
        {'id': 2, 'nome': 'Jardinagem', 'icone': 'grass', 'ativo': false},
      ];
      var atualizacoes = 0;
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path == '/categorias/admin') {
            return jsonResponse({'categorias': categorias});
          }
          if (request.url.path == '/categorias/2' &&
              request.method == 'PATCH') {
            atualizacoes++;
            final input = jsonDecode(request.body) as Map<String, dynamic>;
            categorias[1] = {...categorias[1], ...input};
            return jsonResponse({'categoria': categorias[1]});
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.adminCategorias);
      expect(find.text('Pintura'), findsOneWidget);
      expect(find.text('Jardinagem'), findsOneWidget);

      final busca = find.byType(TextField).first;
      await tester.enterText(busca, 'Pintura');
      await tester.pumpAndSettle();
      expect(find.text('Jardinagem'), findsNothing);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(busca).controller!.text, isEmpty);
      expect(find.text('Jardinagem'), findsOneWidget);

      final inativas = find.byKey(const ValueKey('admin-categorias-inativa'));
      await tester.ensureVisible(inativas);
      await tester.pumpAndSettle();
      await tester.tap(inativas);
      await tester.pumpAndSettle();
      expect(find.text('Pintura'), findsNothing);
      expect(find.text('Jardinagem'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Editar categoria'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('categoria-form-nome')),
        'Jardinagem e poda',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('categoria-form-salvar')),
      );
      await tester.tap(find.byKey(const ValueKey('categoria-form-salvar')));
      await tester.pumpAndSettle();
      expect(atualizacoes, 1);
      expect(find.text('Jardinagem e poda'), findsOneWidget);
      expect(find.text('Pintura'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
