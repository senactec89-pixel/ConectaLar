import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/api_mappers.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

final _previa = FrontendPreviewClient();

Future<void> _mostrar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _preencherSolicitacao(WidgetTester tester) async {
  final data = DateTime.now().add(const Duration(days: 30));
  final campos = {
    'solicitar-data':
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}',
    'solicitar-horario': '10:00',
    'solicitar-descricao': 'Instalar o chuveiro do banheiro social.',
  };
  for (final campo in campos.entries) {
    final finder = find.byKey(ValueKey(campo.key));
    await _mostrar(tester, finder);
    await tester.enterText(finder, campo.value);
  }
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'disponibilidade distingue falha e vazio, preservando formulário',
    (tester) async {
      var consultas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path.endsWith('/disponibilidade')) {
            consultas++;
            return consultas == 1
                ? jsonResponse({'message': 'Indisponível'}, 503)
                : jsonResponse({'disponibilidades': []});
          }
          return null;
        },
      );
      await abrirFrontend(
        tester,
        AppRoutes.solicitarServico,
        arguments: profissionalFromApi(_previa.profissionais.first),
      );
      expect(
        find.text('Não foi possível consultar a disponibilidade.'),
        findsOneWidget,
      );
      expect(find.text('Nenhum horário informado'), findsNothing);
      await _preencherSolicitacao(tester);
      final descricao = tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('solicitar-descricao')),
          )
          .controller!
          .text;
      final retry = find.byKey(
        const ValueKey('disponibilidade-tentar-novamente'),
      );
      await _mostrar(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(consultas, 2);
      expect(find.text('Nenhum horário informado'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('solicitar-descricao')),
            )
            .controller!
            .text,
        descricao,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'endereço com erro ou carregando impede envio até retry bem-sucedido',
    (tester) async {
      var consultas = 0;
      var envios = 0;
      Map<String, dynamic>? enviado;
      final respostaEndereco = Completer<http.Response>();
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/clientes/me/enderecos') {
            consultas++;
            return consultas == 1
                ? jsonResponse({'message': 'Indisponível'}, 503)
                : respostaEndereco.future;
          }
          if (request.url.path.endsWith('/disponibilidade')) {
            return jsonResponse({'disponibilidades': []});
          }
          if (request.method == 'POST' && request.url.path == '/solicitacoes') {
            envios++;
            enviado = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'solicitacao': _previa.pedidos.first});
          }
          return null;
        },
      );
      await abrirFrontend(
        tester,
        AppRoutes.solicitarServico,
        arguments: profissionalFromApi(_previa.profissionais.first),
      );
      expect(
        find.text('Não foi possível carregar seus endereços.'),
        findsOneWidget,
      );
      expect(find.text('Cadastrar endereco'), findsNothing);
      await _preencherSolicitacao(tester);
      final enviar = find.byKey(const ValueKey('solicitar-enviar'));
      await _mostrar(tester, enviar);
      await tester.tap(enviar);
      await tester.pumpAndSettle();
      expect(envios, 0);
      expect(
        find.text(
          'Não foi possível consultar seus endereços. Tente novamente antes de enviar.',
        ),
        findsOneWidget,
      );
      ScaffoldMessenger.of(tester.element(enviar)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('enderecos-tentar-novamente'));
      await _mostrar(tester, retry);
      await tester.tap(retry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Carregando seus endereços…'), findsOneWidget);
      expect(find.text('Cadastrar endereco'), findsNothing);
      await tester.ensureVisible(enviar);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(enviar);
      await tester.pump();
      expect(envios, 0);
      ScaffoldMessenger.of(tester.element(enviar)).removeCurrentSnackBar();
      await tester.pump(const Duration(milliseconds: 300));
      respostaEndereco.complete(
        jsonResponse({
          'enderecos': [_previa.endereco],
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível carregar seus endereços.'),
        findsNothing,
      );
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
      ScaffoldMessenger.of(tester.element(enviar)).clearSnackBars();
      await tester.pumpAndSettle();
      await _mostrar(tester, enviar);
      await tester.tap(enviar);
      await tester.pumpAndSettle();
      expect(envios, 1);
      expect(enviado?['enderecoId'], _previa.endereco['id']);
      expect(enviado?['descricao'], 'Instalar o chuveiro do banheiro social.');
      expect(find.text('Solicitação enviada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'avisos, retry e campos cabem em 360, 390 e 412 com texto 200% e teclado',
    (tester) async {
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/clientes/me/enderecos' ||
              request.url.path.endsWith('/disponibilidade')) {
            return jsonResponse({'message': 'Indisponível'}, 503);
          }
          return null;
        },
      );
      addTearDown(tester.view.resetViewInsets);
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.solicitarServico,
          arguments: profissionalFromApi(_previa.profissionais.first),
          width: width,
          textScale: 2,
        );
        for (final key in [
          'enderecos-tentar-novamente',
          'disponibilidade-tentar-novamente',
        ]) {
          final retry = find.byKey(ValueKey(key));
          await _mostrar(tester, retry);
          expect(retry.hitTestable(), findsOneWidget);
          expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
        }
        await _preencherSolicitacao(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final enviar = find.byKey(const ValueKey('solicitar-enviar'));
        await _mostrar(tester, enviar);
        expect(enviar.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Largura $width');
        tester.view.resetViewInsets();
      }
    },
  );

  testWidgets(
    'detalhes oferecem retry e não consultam de novo ao redimensionar',
    (tester) async {
      var consultas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/solicitacoes/1001' && ++consultas == 1) {
            return jsonResponse({'message': 'Indisponível'}, 503);
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
      expect(
        find.text('Não foi possível carregar esta solicitação.'),
        findsOneWidget,
      );
      expect(find.text('Nenhuma solicitação foi selecionada.'), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(consultas, 2);
      expect(
        find.text('Não foi possível carregar esta solicitação.'),
        findsNothing,
      );
      tester.view.physicalSize = const Size(412, 844);
      await tester.pumpAndSettle();
      expect(consultas, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detalhes distinguem seleção ausente, 404 e resposta inválida', (
    tester,
  ) async {
    var consultas = 0;
    var invalida = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/1001') {
          consultas++;
          return invalida
              ? jsonResponse({'solicitacao': null})
              : jsonResponse({'message': 'Não encontrada'}, 404);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico);
    expect(find.text('Nenhuma solicitação foi selecionada.'), findsOneWidget);
    expect(consultas, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    expect(find.text('Solicitação não encontrada'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    invalida = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1001);
    expect(
      find.text(
        'Não foi possível ler os dados desta solicitação. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Solicitação não encontrada'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(consultas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'meus serviços mantém erro separado de vazio e explica cada filtro',
    (tester) async {
      var consultas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/solicitacoes/me') {
            consultas++;
            return consultas == 1
                ? jsonResponse({'message': 'Indisponível'}, 503)
                : jsonResponse({'solicitacoes': []});
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.meusServicos);
      expect(
        find.text('Não foi possível carregar seus serviços agora.'),
        findsOneWidget,
      );
      expect(find.text('Você ainda não tem solicitações'), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Você ainda não tem solicitações'), findsOneWidget);
      for (final filtro in {
        'aguardando': 'Nenhuma solicitação aguardando resposta',
        'agendados': 'Nenhum atendimento agendado',
        'historico': 'Seu histórico ainda está vazio',
      }.entries) {
        final chip = find.byKey(ValueKey('servicos-filtro-${filtro.key}'));
        await _mostrar(tester, chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(find.text(filtro.value), findsOneWidget);
      }
      expect(consultas, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
