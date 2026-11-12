import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/screens/admin/catalogo_categoria_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('administrador cria serviço pausado na categoria', (
    tester,
  ) async {
    Map<String, dynamic>? salvo;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/admin/catalogo/categorias/5/servicos') {
          if (request.method == 'POST') {
            salvo = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({
              'servico': {'id': 1, ...salvo!},
            }, 201);
          }
          return jsonResponse({
            'servicos': [],
            'paginacao': {'temMais': false},
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      '/catalogo-teste',
      width: 360,
      overrides: {
        '/catalogo-teste': (_) => const CatalogoCategoriaPage(
          categoria: {'id': 5, 'nome': 'Manutenção'},
        ),
      },
    );
    await tester.tap(find.text('Novo serviço'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do serviço'),
      'Montagem de cadeira',
    );
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(salvo?['nome'], 'Montagem de cadeira');
    expect(salvo?.containsKey('ativo'), false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profissional seleciona categoria e serviço do catálogo', (
    tester,
  ) async {
    Map<String, dynamic>? salvo;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/categorias') {
          return jsonResponse({
            'categorias': [
              {'id': 5, 'nome': 'Manutenção'},
            ],
          });
        }
        if (request.url.path == '/categorias/5/servicos') {
          return jsonResponse({
            'servicos': [
              {'id': 12, 'nome': 'Montagem de cadeira'},
            ],
            'paginacao': {'temMais': false},
          });
        }
        if (request.url.path == '/profissionais/me/servicos') {
          if (request.method == 'PUT') {
            salvo = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({
              'servicos': [
                {
                  'id': 77,
                  'nome': 'Montagem de cadeira',
                  ...((salvo!['servicos'] as List).first as Map),
                },
              ],
            });
          }
          return jsonResponse({'servicos': []});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.servicosProfissional, width: 360);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Adicionar serviço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manutenção').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serviço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montagem de cadeira').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect((salvo!['servicos'] as List).single['servicoCatalogoId'], 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente filtra pela identidade do serviço', (tester) async {
    final buscas = <Uri>[];
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/categorias') {
          return jsonResponse({
            'categorias': [
              {'id': 5, 'nome': 'Manutenção', 'ativo': true},
            ],
          });
        }
        if (request.url.path == '/categorias/5/servicos') {
          return jsonResponse({
            'servicos': [
              {'id': 12, 'nome': 'Montagem de cadeira'},
            ],
            'paginacao': {'temMais': false},
          });
        }
        if (request.url.path == '/profissionais') {
          buscas.add(request.url);
          return jsonResponse({
            'profissionais': [],
            'paginacao': {'pagina': 1, 'total': 0, 'temMais': false},
          });
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.busca, width: 360);
    await tester.tap(find.text('Manutenção').first);
    await tester.pumpAndSettle();
    final servico = find.byKey(const ValueKey('busca-catalogo-12'));
    await tester.ensureVisible(servico);
    await tester.tap(servico);
    await tester.pumpAndSettle();
    expect(buscas.last.queryParameters['servicoCatalogoId'], '12');
    expect(buscas.last.queryParameters['categoriaId'], '5');
    expect(tester.takeException(), isNull);
  });
}
