import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  for (final destino in [
    ('Dados pessoais e conta', AppRoutes.perfil),
    ('Atendimentos ainda bloqueados', AppRoutes.documentosProfissional),
  ]) {
    testWidgets('perfil profissional atualiza ao voltar de ${destino.$1}', (
      tester,
    ) async {
      var consultas = 0;
      await configurarFrontend(
        papel: 'profissional',
        responder: (request) async {
          if (request.url.path == '/profissionais/me') {
            consultas++;
            return jsonResponse({
              'profissional': {'id': 9, 'nome': 'Teste'},
            });
          }
          if (request.url.path == '/profissionais/me/documentos') {
            return jsonResponse({
              'documentos': [],
              'habilitacao': {'podeAtender': false},
            });
          }
          return null;
        },
      );
      await abrirFrontend(
        tester,
        AppRoutes.perfilProfissionalPrivado,
        overrides: {
          destino.$2: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar ao perfil'),
            ),
          ),
        },
      );
      final acao = find.text(destino.$1);
      await tester.scrollUntilVisible(
        acao,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(acao);
      await tester.pumpAndSettle();
      final anterior = consultas;
      await tester.tap(find.text('Voltar ao perfil'));
      await tester.pumpAndSettle();
      expect(consultas, anterior + 1);
      expect(find.text('Meu perfil profissional'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
