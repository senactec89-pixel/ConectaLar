import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/models/profissional.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());
  testWidgets('cliente escolhe opções e troca de serviço limpa a seleção', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/categorias/5/servicos/12/opcoes') {
          return jsonResponse({
            'opcoes': [
              {'id': 3, 'nome': 'Pisos'},
            ],
            'paginacao': {'temMais': false},
          });
        }
        if (request.url.path == '/categorias/5/servicos/13/opcoes') {
          return jsonResponse({
            'opcoes': [
              {'id': 4, 'nome': 'Vidros'},
            ],
            'paginacao': {'temMais': false},
          });
        }
        return null;
      },
    );
    const profissional = Profissional(
      id: 1,
      usuarioId: 2,
      nome: 'Profissional fictício',
      descricao: 'Limpeza',
      bairro: 'Centro',
      ofertas: [
        OfertaProfissional(
          id: 10,
          nome: 'Limpeza',
          categoriaId: 5,
          servicoCatalogoId: 12,
        ),
        OfertaProfissional(
          id: 11,
          nome: 'Vidros',
          categoriaId: 5,
          servicoCatalogoId: 13,
        ),
      ],
    );
    await abrirFrontend(
      tester,
      AppRoutes.solicitarServico,
      arguments: profissional,
    );
    final pisos = find.byKey(const ValueKey('solicitar-opcao-3'));
    expect(pisos, findsOneWidget);
    await tester.tap(pisos);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(pisos).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('solicitar-servico')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vidros').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('solicitar-opcao-3')), findsNothing);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('solicitar-opcao-4')),
          )
          .value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('oferta antiga sem vínculo ao catálogo não parece erro de rede', (
    tester,
  ) async {
    var chamadasDeOpcoes = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.endsWith('/opcoes')) chamadasDeOpcoes++;
        return null;
      },
    );
    const profissional = Profissional(
      id: 1,
      usuarioId: 2,
      nome: 'Profissional',
      descricao: 'Serviço legado',
      bairro: 'Centro',
      ofertas: [
        OfertaProfissional(id: 10, nome: 'Serviço legado', categoriaId: 5),
      ],
    );
    await abrirFrontend(
      tester,
      AppRoutes.solicitarServico,
      arguments: profissional,
    );

    expect(find.text('Servico indisponivel para pedidos.'), findsOneWidget);
    final enviar = find.byKey(const ValueKey('solicitar-enviar'));
    expect(tester.widget<FilledButton>(enviar).onPressed, isNull);
    expect(chamadasDeOpcoes, 0);
    expect(tester.takeException(), isNull);
  });
}
