import 'dart:async';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

Object _notificacoes(bool lida) => {
  'notificacoes': [
    {
      'id': 1,
      'titulo': 'Pedido atualizado',
      'mensagem': 'Confira os detalhes.',
      'lida': lida,
      'tipo': 'solicitacao',
      'recursoTipo': 'solicitacao',
      'recursoId': 1001,
      'criadoEm': '2026-10-11T12:00:00Z',
    },
  ],
};

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('notificações tratam falha ao marcar e permitem tentar de novo', (
    tester,
  ) async {
    var patches = 0;
    var lida = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/notificacoes/me') {
          return jsonResponse(_notificacoes(lida));
        }
        if (request.method == 'PATCH') {
          if (++patches == 1) return jsonResponse({'message': 'Falha'}, 503);
          lida = true;
          return jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.notificacoes);
    await tester.tap(find.byTooltip('Marcar todas como lidas'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível atualizar suas notificações'),
      findsOneWidget,
    );
    expect(lida, isFalse);
    await tester.tap(find.byTooltip('Marcar todas como lidas'));
    await tester.pumpAndSettle();
    expect(patches, 2);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notificações bloqueiam ações duplicadas durante envio', (
    tester,
  ) async {
    var patches = 0;
    final resposta = Completer<http.Response>();
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/notificacoes/me') {
          return jsonResponse(_notificacoes(false));
        }
        if (request.method == 'PATCH') {
          patches++;
          return resposta.future;
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.notificacoes);
    await tester.tap(find.byTooltip('Marcar todas como lidas'));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.done_all_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    expect(patches, 1);
    resposta.complete(jsonResponse({'ok': true}));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.done_all_rounded),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('notificações recarregam ao voltar dos detalhes', (tester) async {
    var consultas = 0;
    var lida = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/notificacoes/me') {
          consultas++;
          return jsonResponse(_notificacoes(lida));
        }
        if (request.method == 'PATCH') {
          lida = true;
          return jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.notificacoes,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar aos avisos'),
          ),
        ),
      },
    );
    await tester.tap(find.text('Pedido atualizado'));
    await tester.pumpAndSettle();
    expect(consultas, 1);
    await tester.tap(find.text('Voltar aos avisos'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao marcar como lida não impede abrir o pedido', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/notificacoes/me') {
          return jsonResponse(_notificacoes(false));
        }
        if (request.method == 'PATCH') {
          return jsonResponse({'message': 'Falha'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.notificacoes,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Pedido aberto'),
          ),
        ),
      },
    );
    await tester.tap(find.text('Pedido atualizado'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido aberto'), findsOneWidget);
    await tester.tap(find.text('Pedido aberto'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido atualizado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
