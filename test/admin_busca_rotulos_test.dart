import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('cada lista administrativa identifica sua busca', (tester) async {
    final consultas = <Uri>[];
    const casos = [
      (
        AppRoutes.adminDocumentos,
        '/documentos-verificacao',
        'documentos',
        'Buscar documento',
      ),
      (
        AppRoutes.adminDenuncias,
        '/denuncias/moderacao',
        'denuncias',
        'Buscar denúncia',
      ),
      (
        AppRoutes.adminAvaliacoes,
        '/avaliacoes/moderacao',
        'avaliacoes',
        'Buscar avaliação',
      ),
      (
        AppRoutes.adminCategorias,
        '/categorias/admin',
        'categorias',
        'Buscar categoria',
      ),
      (
        AppRoutes.adminAuditoria,
        '/admin/painel/auditoria',
        'eventos',
        'Buscar registro',
      ),
      (
        AppRoutes.adminUsuarios,
        '/admin/usuarios',
        'usuarios',
        'Buscar nome ou e-mail',
      ),
    ];
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        for (final caso in casos) {
          if (request.url.path == caso.$2) {
            consultas.add(request.url);
            return jsonResponse({caso.$3: []});
          }
        }
        return null;
      },
    );
    for (final caso in casos) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(tester, caso.$1, width: 360, textScale: 2);
      final campo = find.widgetWithText(TextField, caso.$4);
      expect(campo, findsOneWidget);
      expect(find.text('Use a busca do teclado para aplicar.'), findsOneWidget);
      await tester.ensureVisible(campo);
      await tester.enterText(campo, 'exemplo');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(consultas.last.path, caso.$2);
      expect(consultas.last.queryParameters['termo'], 'exemplo');
      expect(tester.takeException(), isNull, reason: caso.$1);
    }
  });
}
