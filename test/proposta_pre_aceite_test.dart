import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

Map<String, dynamic> pedido({
  Map<String, dynamic>? proposta,
  String status = 'aguardando_resposta',
}) => {
  'id': 1001,
  'cliente': {'id': 501, 'nome': 'Cliente'},
  'profissional': {'id': 1, 'usuarioId': 101, 'nome': 'Profissional'},
  'categoria': {'id': 1, 'nome': 'Limpeza'},
  'status': status,
  'descricao': 'Limpeza residencial conforme o pedido.',
  'bairroAtendimento': 'Centro',
  'dataServico': '2099-10-25',
  'horarioServico': '14:00',
  'duracaoMinutos': 60,
  'intervaloMinutos': 30,
  'propostaPreAceite': proposta,
  'propostasPreAceite': proposta == null ? [] : [proposta],
  'prazoRespostaEm': proposta == null ? '2099-10-20T12:00:00Z' : null,
  'prazoInatividadeEm': proposta == null ? null : '2099-10-24T12:00:00Z',
  'criadoEm': '2026-10-20T12:00:00Z',
  'atualizadoEm': '2026-10-20T12:00:00Z',
};

Future<void> mostrar(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('cliente confirma antes de aceitar a proposta e agendar', (
    tester,
  ) async {
    final proposta = {
      'id': 7,
      'status': 'pendente',
      'dataServico': '2099-10-26',
      'horarioServico': '15:00',
      'escopo': 'Limpeza dos ambientes combinados.',
      'venceEm': '2099-10-23T12:00:00Z',
    };
    var atual = pedido(proposta: proposta);
    Map<String, dynamic>? corpo;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001' &&
            request.method == 'GET') {
          return jsonResponse({'solicitacao': atual});
        }
        if (request.url.path == '/solicitacoes/1001/propostas/7/responder') {
          corpo = jsonDecode(request.body) as Map<String, dynamic>;
          atual = pedido(
            proposta: {...proposta, 'status': 'aceita'},
            status: 'aceita_agendada',
          );
          return jsonResponse({'solicitacao': atual});
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    await mostrar(tester, 'aceitar-proposta-pre-aceite');
    await tester.tap(find.byKey(const ValueKey('aceitar-proposta-pre-aceite')));
    await tester.pumpAndSettle();
    expect(corpo, isNull);
    expect(find.text('Aceitar proposta?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmar-resposta-proposta-pre-aceite')),
    );
    await tester.pumpAndSettle();
    expect(corpo, {'aceitar': true});
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Aceita e agendada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profissional mantém o escopo digitado ao falhar o envio', (
    tester,
  ) async {
    var tentativas = 0;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001' &&
            request.method == 'GET') {
          return jsonResponse({'solicitacao': pedido()});
        }
        if (request.url.path == '/solicitacoes/1001/propostas') {
          tentativas++;
          return jsonResponse({'message': 'Serviço indisponível.'}, 503);
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    await mostrar(tester, 'propor-antes-aceite');
    await tester.tap(find.byKey(const ValueKey('propor-antes-aceite')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('proposta-pre-aceite-escopo')),
      'Limpeza completa dos ambientes internos.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('proposta-pre-aceite-enviar')),
    );
    await tester.tap(find.byKey(const ValueKey('proposta-pre-aceite-enviar')));
    await tester.pumpAndSettle();

    expect(tentativas, 1);
    expect(
      find.text('Limpeza completa dos ambientes internos.'),
      findsOneWidget,
    );
    expect(find.text('Propor antes do aceite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
