import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

Map<String, dynamic> _pedido(String status, {int clienteId = 501}) => {
  'id': 1001,
  'cliente': {'id': clienteId, 'nome': 'Cliente'},
  'profissional': {'id': 1, 'usuarioId': 101, 'nome': 'Profissional'},
  'categoria': {'id': 1, 'nome': 'Manutenção'},
  'descricao': 'Atendimento de manutenção',
  'bairroAtendimento': 'Centro',
  'precoInicial': null,
  'dataServico': '2026-10-20',
  'horarioServico': '14:00',
  'status': status,
  'criadoEm': '2026-10-12T12:00:00Z',
  'atualizadoEm': '2026-10-12T12:00:00Z',
};

const _mensagem = {
  'id': 1,
  'solicitacaoId': 1001,
  'autor': {'id': 101},
  'conteudo': 'Mensagem anterior preservada',
  'criadoEm': '2026-10-12T12:00:00Z',
};

void main() {
  tearDown(() => AppServices.instance.api.close());

  for (final status in ['recusada', 'cancelada', 'conclusao_confirmada']) {
    testWidgets('chat $status não convida a enviar e preserva histórico', (
      tester,
    ) async {
      var historicoVazio = true;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/solicitacoes/1001') {
            return jsonResponse({'solicitacao': _pedido(status)});
          }
          if (request.url.path.endsWith('/mensagens')) {
            return jsonResponse({
              'mensagens': historicoVazio ? [] : [_mensagem],
            });
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);

      expect(find.byKey(const ValueKey('chat-mensagem')), findsNothing);
      expect(find.byKey(const ValueKey('chat-enviar')), findsNothing);
      expect(find.textContaining('Use a conversa'), findsNothing);
      expect(find.textContaining('Conversa encerrada:'), findsOneWidget);
      expect(find.textContaining('Não houve mensagens'), findsOneWidget);

      historicoVazio = false;
      await tester.tap(find.byTooltip('Atualizar conversa'));
      await tester.pumpAndSettle();
      expect(find.text('Mensagem anterior preservada'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-enviar')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final papel in ['cliente', 'profissional', 'empresa']) {
    testWidgets('participante $papel mantém envio nos dois estados ativos', (
      tester,
    ) async {
      var status = 'aguardando_resposta';
      await configurarFrontend(
        papel: papel,
        responder: (request) async {
          if (request.url.path == '/solicitacoes/1001') {
            return jsonResponse({'solicitacao': _pedido(status)});
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
      expect(find.byKey(const ValueKey('chat-mensagem')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('chat-enviar')))
            .onPressed,
        isNotNull,
      );

      status = 'aceita_agendada';
      await tester.tap(find.byTooltip('Atualizar conversa'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-mensagem')), findsOneWidget);
      expect(find.text('Agendamento registrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final papel in ['administrador', 'cliente']) {
    testWidgets('$papel sem participação consulta sem receber compositor', (
      tester,
    ) async {
      await configurarFrontend(
        papel: papel,
        responder: (request) async {
          if (request.url.path == '/solicitacoes/1001') {
            return jsonResponse({
              'solicitacao': _pedido('aguardando_resposta', clienteId: 999),
            });
          }
          if (request.url.path.endsWith('/mensagens')) {
            return jsonResponse({'mensagens': []});
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
      expect(find.text('Conversa somente para consulta.'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-mensagem')), findsNothing);
      expect(find.byKey(const ValueKey('chat-enviar')), findsNothing);
      expect(find.textContaining('Use a conversa'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final code in [400, 403, 409]) {
    testWidgets('envio recusado com $code recarrega fechamento sem reenviar', (
      tester,
    ) async {
      var status = 'aguardando_resposta';
      var envios = 0;
      var consultas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/solicitacoes/1001') {
            consultas++;
            return jsonResponse({'solicitacao': _pedido(status)});
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/mensagens')) {
            envios++;
            status = 'cancelada';
            return jsonResponse({'message': 'Dados inválidos.'}, code);
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
      final campo = find.byKey(const ValueKey('chat-mensagem'));
      final controller = tester.widget<TextField>(campo).controller!;
      await tester.enterText(campo, 'Rascunho não enviado');
      await tester.tap(find.byKey(const ValueKey('chat-enviar')));
      await tester.pumpAndSettle();

      expect(envios, 1);
      expect(consultas, 2);
      expect(controller.text, 'Rascunho não enviado');
      expect(find.byKey(const ValueKey('chat-enviar')), findsNothing);
      expect(
        find.textContaining('Conversa encerrada: Cancelada'),
        findsOneWidget,
      );
      expect(find.textContaining('Novas mensagens não podem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('falha de rede preserva rascunho e não simula encerramento', (
    tester,
  ) async {
    var consultas = 0;
    var envios = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001') {
          consultas++;
          return jsonResponse({'solicitacao': _pedido('aceita_agendada')});
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/mensagens')) {
          envios++;
          return jsonResponse({'message': 'Indisponível'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
    await tester.enterText(
      find.byKey(const ValueKey('chat-mensagem')),
      'Mensagem para depois',
    );
    await tester.tap(find.byKey(const ValueKey('chat-enviar')));
    await tester.pumpAndSettle();
    expect(envios, 1);
    expect(consultas, 1);
    expect(find.text('Mensagem para depois'), findsOneWidget);
    expect(find.textContaining('Conversa encerrada:'), findsNothing);
    expect(find.text('Não foi possível enviar a mensagem.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voltar dos detalhes atualiza encerramento da conversa', (
    tester,
  ) async {
    var status = 'aceita_agendada';
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001') {
          return jsonResponse({'solicitacao': _pedido(status)});
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.conversa,
      arguments: 1001,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              status = 'conclusao_confirmada';
              Navigator.pop(context);
            },
            child: const Text('Concluir e retornar'),
          ),
        ),
      },
    );
    await tester.tap(find.byTooltip('Ver detalhes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir e retornar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-enviar')), findsNothing);
    expect(
      find.textContaining('Conversa encerrada: Conclusão confirmada'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista atualiza conversas ativas ao retornar', (tester) async {
    var status = 'aguardando_resposta';
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me') {
          consultas++;
          return jsonResponse({
            'solicitacoes': [_pedido(status)],
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.chat,
      overrides: {
        AppRoutes.conversa: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              status = 'cancelada';
              Navigator.pop(context);
            },
            child: const Text('Voltar à lista'),
          ),
        ),
      },
    );
    await tester.tap(find.byKey(const ValueKey('chat-solicitacao-1001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar à lista'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.byKey(const ValueKey('chat-solicitacao-1001')), findsNothing);
    expect(find.text('Nenhuma conversa ativa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat encerrado cabe em 360, 390 e 412 com texto 200%', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001') {
          return jsonResponse({'solicitacao': _pedido('conclusao_confirmada')});
        }
        if (request.url.path.endsWith('/mensagens')) {
          return jsonResponse({'mensagens': []});
        }
        return null;
      },
    );
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.conversa,
        arguments: 1001,
        width: width,
        textScale: 2,
      );
      expect(find.textContaining('Conversa encerrada:'), findsOneWidget);
      expect(find.textContaining('Não houve mensagens'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$width pixels');
    }
  });
}
