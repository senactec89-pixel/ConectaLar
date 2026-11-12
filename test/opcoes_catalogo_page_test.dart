import 'dart:convert';

import 'package:conectarlar_app/screens/admin/opcoes_catalogo_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());
  testWidgets('administrador cria opção sem ativá-la', (tester) async {
    Map<String, dynamic>? salvo;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path ==
            '/admin/catalogo/categorias/5/servicos/12/opcoes') {
          if (request.method == 'POST') {
            salvo = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({
              'opcao': {'id': 4, ...salvo!, 'ativo': false},
            }, 201);
          }
          return jsonResponse({
            'opcoes': [],
            'paginacao': {'temMais': false},
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      '/opcoes-teste',
      overrides: {
        '/opcoes-teste': (_) => const OpcoesCatalogoPage(
          categoriaId: 5,
          servico: {'id': 12, 'nome': 'Limpeza'},
        ),
      },
    );
    await tester.tap(find.text('Nova opção'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da opção'),
      'Pisos',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(salvo, {'nome': 'Pisos'});
    expect(tester.takeException(), isNull);
  });
}
