import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

final _previa = FrontendPreviewClient();
const _relato = 'A outra parte enviou mensagens ofensivas durante a conversa.';

Future<void> _mostrar(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  for (final papel in ['cliente', 'profissional', 'empresa']) {
    for (final status in ['aguardando_resposta', 'aceita_agendada']) {
      testWidgets('$papel denuncia em $status sem cancelar o atendimento', (
        tester,
      ) async {
        final pedido = {..._previa.pedidos.first, 'status': status};
        final escritas = <String>[];
        Map<String, dynamic>? enviada;
        await configurarFrontend(
          papel: papel,
          responder: (request) async {
            if (request.method == 'GET' &&
                request.url.path == '/solicitacoes/1001') {
              return jsonResponse({'solicitacao': pedido});
            }
            if (request.method != 'GET' && request.url.path != '/auth/login') {
              escritas.add('${request.method} ${request.url.path}');
              enviada = jsonDecode(request.body) as Map<String, dynamic>;
              return jsonResponse({
                'denuncia': {'id': 1, 'status': 'aberta'},
              });
            }
            return null;
          },
        );
        await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
        await _mostrar(tester, 'detalhes-denunciar');
        expect(find.text('Ajuda e segurança'), findsOneWidget);
        final titulo = papel == 'cliente'
            ? 'Denunciar profissional'
            : 'Denunciar cliente';
        expect(find.text(titulo), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('detalhes-denunciar')));
        await tester.pumpAndSettle();
        expect(find.text(titulo), findsOneWidget);
        expect(
          find.text(
            'Não é preciso cancelar para denunciar. O envio não altera a situação da solicitação nem aplica punições automaticamente.',
          ),
          findsOneWidget,
        );
        await _mostrar(tester, 'denuncia-descricao');
        await tester.enterText(
          find.byKey(const ValueKey('denuncia-descricao')),
          _relato,
        );
        await _mostrar(tester, 'denuncia-enviar');
        await tester.tap(find.byKey(const ValueKey('denuncia-enviar')));
        await tester.pumpAndSettle();

        expect(escritas, ['POST /solicitacoes/1001/denuncias']);
        expect(enviada, {
          'denunciadoId': papel == 'cliente' ? 101 : 501,
          'motivo': 'Conduta inadequada',
          'descricao': _relato,
        });
        expect(find.text('Detalhes do serviço'), findsOneWidget);
        expect(
          find.text('Denúncia enviada para análise administrativa.'),
          findsOneWidget,
        );
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(
          find.text(
            status == 'aguardando_resposta'
                ? 'Aguardando resposta'
                : 'Aceita e agendada',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('falha preserva relato e motivo, envio bloqueia repetição', (
    tester,
  ) async {
    var envios = 0;
    final resposta = Completer<http.Response>();
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001/denuncias') {
          envios++;
          return envios == 1
              ? resposta.future
              : jsonResponse({
                  'denuncia': {'id': 1},
                });
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    await _mostrar(tester, 'detalhes-denunciar');
    await tester.tap(find.byKey(const ValueKey('detalhes-denunciar')));
    await tester.pumpAndSettle();
    await _mostrar(tester, 'denuncia-motivo');
    await tester.tap(find.byKey(const ValueKey('denuncia-motivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conteúdo ofensivo').last);
    await tester.pumpAndSettle();
    await _mostrar(tester, 'denuncia-descricao');
    await tester.enterText(
      find.byKey(const ValueKey('denuncia-descricao')),
      _relato,
    );
    await _mostrar(tester, 'denuncia-enviar');
    final enviar = find.byKey(const ValueKey('denuncia-enviar'));
    await tester.tap(enviar);
    await tester.pump();
    expect(tester.widget<FilledButton>(enviar).onPressed, isNull);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('denuncia-descricao')),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(enviar);
    await tester.pump();
    expect(envios, 1);
    resposta.complete(
      jsonResponse({'message': 'Tente novamente mais tarde.'}, 503),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tente novamente mais tarde.'), findsOneWidget);
    expect(find.text('Denunciar atendimento'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('denuncia-descricao')),
          )
          .controller!
          .text,
      _relato,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('denuncia-motivo')),
          )
          .initialValue,
      'Conteudo ofensivo',
    );
    ScaffoldMessenger.of(tester.element(enviar)).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await _mostrar(tester, 'denuncia-enviar');
    await tester.tap(enviar);
    await tester.pumpAndSettle();
    expect(envios, 2);
    expect(find.text('Detalhes do serviço'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conta sem vínculo não recebe ação nem formulário de denúncia', (
    tester,
  ) async {
    final pedido = {
      ..._previa.pedidos.first,
      'cliente': {'id': 999},
    };
    await configurarFrontend(
      responder: (request) async => request.url.path == '/solicitacoes/1001'
          ? jsonResponse({'solicitacao': pedido})
          : null,
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detalhes-denunciar')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await abrirFrontend(tester, AppRoutes.denunciarServico, arguments: 1001);
    expect(find.text('Denúncia indisponível'), findsOneWidget);
    expect(find.byKey(const ValueKey('denuncia-enviar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denúncia cabe em 360, 390 e 412 com texto 200% e teclado', (
    tester,
  ) async {
    await configurarFrontend();
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.detalhesServico,
        arguments: 1001,
        width: width,
        textScale: 2,
      );
      await _mostrar(tester, 'detalhes-denunciar');
      expect(
        find.byKey(const ValueKey('detalhes-denunciar')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('detalhes-denunciar')));
      await tester.pumpAndSettle();
      await _mostrar(tester, 'denuncia-motivo');
      await tester.tap(find.byKey(const ValueKey('denuncia-motivo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Problema no atendimento').last);
      await tester.pumpAndSettle();
      await _mostrar(tester, 'denuncia-descricao');
      await tester.enterText(
        find.byKey(const ValueKey('denuncia-descricao')),
        _relato,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await _mostrar(tester, 'denuncia-enviar');
      expect(
        find.byKey(const ValueKey('denuncia-enviar')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: '$width px');
      tester.view.resetViewInsets();
    }
  });
}
