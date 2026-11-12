import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());
  testWidgets('primeira resposta abre negociação, não agenda', (tester) async {
    var iniciada = false;
    final caminhos = <String>[];
    Map<String, dynamic> pedido() => {
      'id': 7,
      'servicoId': 10,
      'nomeServico': 'Limpeza',
      'servicoSnapshot': {
        'categoriaId': 5,
        'servicoCatalogoId': 12,
        'nomeServico': 'Limpeza',
      },
      'cliente': {'id': 501, 'nome': 'Cliente fictício'},
      'profissional': {
        'id': 2,
        'usuarioId': 101,
        'nome': 'Profissional fictício',
      },
      'categoria': {'id': 5, 'nome': 'Limpeza'},
      'status': 'aguardando_resposta',
      'descricao': 'Pedido fictício',
      'bairroAtendimento': 'Centro',
      'dataServico': '2030-01-05',
      'horarioServico': '10:00',
      'negociacaoIniciada': iniciada,
      'eventos': [],
    };
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        caminhos.add('${request.method} ${request.url.path}');
        if (request.url.path == '/solicitacoes/7')
          return jsonResponse({'solicitacao': pedido()});
        if (request.url.path == '/solicitacoes/7/opcoes')
          return jsonResponse({
            'opcoes': [
              {'id': 3, 'nome': 'Pisos'},
            ],
          });
        if (request.url.path == '/solicitacoes/7/negociacao') {
          iniciada = true;
          return jsonResponse({
            'solicitacao': pedido(),
            'negociacaoIniciada': true,
          }, 201);
        }
        if (request.url.path == '/solicitacoes/7/propostas-atendimento')
          return jsonResponse({
            'propostas': [],
            'paginacao': {'temMais': false},
          });
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 7);
    await tester.scrollUntilVisible(
      find.text('Iniciar negociação'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Conversar'), findsNothing);
    await tester.tap(find.text('Iniciar negociação'));
    await tester.pumpAndSettle();
    expect(caminhos, contains('POST /solicitacoes/7/negociacao'));
    expect(caminhos, isNot(contains('PATCH /solicitacoes/7/aceitar')));
    expect(find.text('Conversar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Criar proposta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Criar proposta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
