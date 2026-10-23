import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('chat mostra erro recuperável e atualiza mensagens recebidas', (
    tester,
  ) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.endsWith('/mensagens')) {
          if (++consultas == 1) return jsonResponse({'message': 'Falha'}, 503);
          return jsonResponse({
            'mensagens': [
              {
                'id': consultas,
                'solicitacaoId': 1001,
                'autor': {'id': 101},
                'conteudo': 'Mensagem recebida $consultas',
                'criadoEm': '2026-10-11T12:00:00Z',
              },
            ],
          });
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Mensagem recebida 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Atualizar conversa'));
    await tester.pumpAndSettle();
    expect(find.text('Mensagem recebida 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat preserva mensagem quando envio falha', (tester) async {
    await configurarFrontend(
      responder: (request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/mensagens')) {
          return jsonResponse({'message': 'Falha'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
    await tester.enterText(
      find.byKey(const ValueKey('chat-mensagem')),
      'Mensagem para tentar novamente',
    );
    await tester.tap(find.byKey(const ValueKey('chat-enviar')));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível enviar a mensagem.'), findsOneWidget);
    expect(find.text('Mensagem para tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat mantém leitura e permite ir às mensagens recentes', (
    tester,
  ) async {
    var total = 24;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.endsWith('/mensagens') &&
            request.method == 'GET') {
          return jsonResponse({
            'mensagens': [
              for (var i = 1; i <= total; i++)
                {
                  'id': i,
                  'solicitacaoId': 1001,
                  'autor': {'id': 101},
                  'conteudo': 'Mensagem $i',
                  'criadoEm': '2026-10-11T12:00:00Z',
                },
            ],
          });
        }
        if (request.url.path.endsWith('/mensagens') &&
            request.method == 'POST') {
          total++;
          return jsonResponse({'ok': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
    final lista = tester.widget<ListView>(find.byType(ListView));
    final rolagem = lista.controller!;
    expect(rolagem.offset, closeTo(rolagem.position.maxScrollExtent, 1));
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    final posicaoDeLeitura = rolagem.offset;
    expect(find.byKey(const ValueKey('chat-ir-recentes')), findsOneWidget);
    total++;
    await tester.tap(find.byTooltip('Atualizar conversa'));
    await tester.pumpAndSettle();
    expect(rolagem.offset, closeTo(posicaoDeLeitura, 1));
    await tester.tap(find.byKey(const ValueKey('chat-ir-recentes')));
    await tester.pumpAndSettle();
    expect(rolagem.offset, closeTo(rolagem.position.maxScrollExtent, 1));
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-mensagem')),
      'Mensagem nova',
    );
    await tester.tap(find.byKey(const ValueKey('chat-enviar')));
    await tester.pumpAndSettle();
    expect(rolagem.offset, closeTo(rolagem.position.maxScrollExtent, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat vazio cabe com texto ampliado e teclado nas três larguras',
    (tester) async {
      await configurarFrontend(
        responder: (request) async {
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
          textScale: 1.4,
        );
        expect(find.textContaining('Ainda não há mensagens'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.tap(find.byKey(const ValueKey('chat-mensagem')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      }
      addTearDown(tester.view.resetViewInsets);
    },
  );

  testWidgets('chat carrega mensagens anteriores sem duplicar as recentes', (
    tester,
  ) async {
    final paginas = <String?>[];
    await configurarFrontend(
      responder: (request) async {
        if (!request.url.path.endsWith('/mensagens') ||
            request.method != 'GET') {
          return null;
        }
        final pagina = request.url.queryParameters['pagina'] ?? '1';
        paginas.add(pagina);
        final id = pagina == '1' ? 2 : 1;
        return jsonResponse({
          'paginacao': {
            'pagina': int.parse(pagina),
            'limite': 20,
            'total': 2,
            'totalPaginas': 2,
            'temMais': pagina == '1',
          },
          'mensagens': [
            {
              'id': id,
              'solicitacaoId': 1001,
              'autor': {'id': 101},
              'conteudo': id == 1 ? 'Mensagem anterior' : 'Mensagem recente',
              'criadoEm': id == 1
                  ? '2026-10-11T11:00:00Z'
                  : '2026-10-11T12:00:00Z',
            },
          ],
        });
      },
    );
    await abrirFrontend(tester, AppRoutes.conversa, arguments: 1001);
    expect(find.text('Mensagem recente'), findsOneWidget);
    expect(find.text('Mensagem anterior'), findsNothing);

    final anteriores = find.byKey(const ValueKey('chat-carregar-anteriores'));
    await tester.ensureVisible(anteriores);
    await tester.tap(anteriores);
    await tester.pumpAndSettle();

    expect(paginas, ['1', '2']);
    expect(find.text('Mensagem anterior'), findsOneWidget);
    expect(find.text('Mensagem recente'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-carregar-anteriores')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
