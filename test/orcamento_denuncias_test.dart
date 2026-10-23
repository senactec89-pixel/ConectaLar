import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

Map<String, dynamic> _pedido({
  Map<String, dynamic>? orcamento,
  List<Map<String, dynamic>> orcamentos = const [],
  double? precoFinal,
}) => {
  'id': 1001,
  'servicoId': 10,
  'nomeServico': 'Instalacao eletrica',
  'cliente': {'id': 501, 'nome': 'Cliente'},
  'profissional': {
    'id': 1,
    'usuarioId': 101,
    'nome': 'Carlos Silva',
    'verificado': true,
  },
  'categoria': {'id': 1, 'nome': 'Eletrica'},
  'status': 'aceita_agendada',
  'avaliado': false,
  'descricao': 'Instalacao eletrica completa na residencia.',
  'bairroAtendimento': 'Centro',
  'dataServico': '2099-10-25',
  'horarioServico': '14:00',
  'duracaoMinutos': 60,
  'intervaloMinutos': 30,
  'precoInicial': 80,
  'precoFinal': precoFinal,
  'orcamento': orcamento,
  'orcamentos': orcamentos,
  'reagendamento': null,
  'reagendamentos': const [],
  'eventos': const [],
  'enderecoId': null,
  'enderecoProtegido': false,
  'enderecoCompletoLiberado': false,
  'criadoEm': '2026-10-20T12:00:00Z',
  'atualizadoEm': '2026-10-20T12:00:00Z',
};

Future<void> _mostrar(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('cliente aceita orcamento e recebe o preco final confirmado', (
    tester,
  ) async {
    final proposta = {
      'id': 8,
      'propostoPorId': 101,
      'valor': 150.5,
      'descricao': 'Servico e materiais descritos no atendimento.',
      'status': 'pendente',
      'respondidoEm': null,
      'criadoEm': '2026-10-22T12:00:00Z',
    };
    var pedido = _pedido(orcamento: proposta, orcamentos: [proposta]);
    String? chamada;
    Map<String, dynamic>? corpo;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001' &&
            request.method == 'GET') {
          return jsonResponse({'solicitacao': pedido});
        }
        if (request.url.path == '/solicitacoes/1001/orcamentos/responder') {
          chamada = request.method;
          corpo = jsonDecode(request.body) as Map<String, dynamic>;
          final aceito = {...proposta, 'status': 'aceito'};
          pedido = _pedido(
            orcamento: aceito,
            orcamentos: [aceito],
            precoFinal: 150.5,
          );
          return jsonResponse({'solicitacao': pedido});
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    await _mostrar(tester, 'orcamento-aceitar');
    expect(find.text('R\$ 150,50'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('orcamento-aceitar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orcamento-confirmar-aceite')));
    await tester.pumpAndSettle();

    expect(chamada, 'PATCH');
    expect(corpo, {'aceitar': true});
    expect(find.byTooltip('Aceito'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Preço final acordado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profissional envia proposta com valor e escopo preservados', (
    tester,
  ) async {
    var pedido = _pedido();
    Map<String, dynamic>? corpo;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001' &&
            request.method == 'GET') {
          return jsonResponse({'solicitacao': pedido});
        }
        if (request.url.path == '/solicitacoes/1001/orcamentos') {
          corpo = jsonDecode(request.body) as Map<String, dynamic>;
          final proposta = {
            'id': 9,
            'propostoPorId': 101,
            'valor': 175.9,
            'descricao': corpo!['descricao'],
            'status': 'pendente',
            'respondidoEm': null,
            'criadoEm': '2026-10-22T12:00:00Z',
          };
          pedido = _pedido(orcamento: proposta, orcamentos: [proposta]);
          return jsonResponse({'solicitacao': pedido}, 201);
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    await _mostrar(tester, 'orcamento-propor');
    await tester.tap(find.byKey(const ValueKey('orcamento-propor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orcamento-enviar')));
    await tester.pump();
    expect(
      find.text('Informe um valor final válido e maior que zero.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('orcamento-valor')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('orcamento-valor')),
      '175,90',
    );
    await tester.enterText(
      find.byKey(const ValueKey('orcamento-descricao')),
      'Inclui instalacao completa e materiais eletricos.',
    );
    await tester.tap(find.byKey(const ValueKey('orcamento-enviar')));
    await tester.pumpAndSettle();

    expect(corpo, {
      'valor': 175.9,
      'descricao': 'Inclui instalacao completa e materiais eletricos.',
    });
    expect(find.text('R\$ 175,90'), findsOneWidget);
    expect(find.text('Aguardando a decisão do cliente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('historico mostra somente denuncias enviadas e decisao', (
    tester,
  ) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path != '/denuncias/me') return null;
        consultas++;
        return jsonResponse({
          'denuncias': [
            {
              'id': 4,
              'solicitacaoId': 1001,
              'denuncianteId': 501,
              'denunciadoId': 101,
              'denunciado': {
                'id': 101,
                'nome': 'Carlos Silva',
                'tipo': 'profissional',
              },
              'atendimento': {
                'id': 1001,
                'nomeServico': 'Instalacao eletrica',
                'dataServico': '2026-10-25',
                'profissional': 'Carlos Silva',
              },
              'motivo': 'Conduta inadequada',
              'descricao': 'Relato completo enviado para a equipe analisar.',
              'status': 'resolvida',
              'decisao': 'Relato analisado e medidas administrativas tomadas.',
              'analisadoEm': '2026-10-23T13:00:00Z',
              'criadoEm': '2026-10-22T12:00:00Z',
              'atualizadoEm': '2026-10-23T13:00:00Z',
            },
          ],
        });
      },
    );

    await abrirFrontend(tester, AppRoutes.minhasDenuncias);
    expect(consultas, 1);
    expect(find.text('Resolvida'), findsOneWidget);
    expect(find.text('Pessoa denunciada: Carlos Silva'), findsOneWidget);
    expect(
      find.text('Relato analisado e medidas administrativas tomadas.'),
      findsOneWidget,
    );
    expect(find.text('Ver atendimento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
