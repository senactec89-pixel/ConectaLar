import 'dart:convert';

import 'package:conectarlar_app/models/solicitacao.dart';
import 'package:conectarlar_app/screens/servicos/propostas_atendimento_panel.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('profissional envia proposta com itens e valor', (tester) async {
    Map<String, dynamic>? enviada;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/solicitacoes/7/propostas-atendimento') {
          if (request.method == 'POST') {
            enviada = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'propostaId': 22}, 201);
          }
          return jsonResponse({
            'paginacao': {'temMais': false},
            'propostas': [],
          });
        }
        if (request.url.path == '/categorias/5/servicos/12/opcoes') {
          return jsonResponse({
            'opcoes': [
              {'id': 3, 'nome': 'Pisos'},
            ],
            'paginacao': {'temMais': false},
          });
        }
        return null;
      },
    );
    final pedido = Solicitacao(
      id: 7,
      clienteId: 1,
      profissionalId: 2,
      categoriaId: 5,
      servicoCatalogoId: 12,
      descricao: 'Teste',
      dataServico: DateTime(2030, 1, 5),
      horarioServico: '10:00',
      precoInicial: 100,
      status: StatusSolicitacao.aguardandoResposta,
      criadoEm: DateTime(2029),
      atualizadoEm: DateTime(2029),
    );
    await abrirFrontend(
      tester,
      '/proposta-profissional',
      width: 360,
      textScale: 2,
      overrides: {
        '/proposta-profissional': (_) => Scaffold(
          body: SingleChildScrollView(
            child: PropostasAtendimentoPanel(
              solicitacao: pedido,
              opcoesSolicitadas: const [
                {'id': 3, 'nome': 'Pisos'},
              ],
              cliente: false,
              profissional: true,
              negociacaoIniciada: true,
            ),
          ),
        ),
      },
    );
    await tester.ensureVisible(find.text('Criar proposta'));
    await tester.tap(find.text('Criar proposta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor em reais'),
      '150,50',
    );
    await tester.ensureVisible(
      find.byKey(const Key('proposal-duration-select')),
    );
    await tester.tap(find.byKey(const Key('proposal-duration-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1h30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proposal-duration-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizada').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('proposal-duration-hours')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('proposal-duration-minutes')),
      '15',
    );
    await tester.pumpAndSettle();
    expect(find.text('Total: 3h15'), findsOneWidget);
    await tester.ensureVisible(find.text('Enviar proposta'));
    await tester.tap(find.text('Enviar proposta'));
    await tester.pumpAndSettle();
    expect(enviada, {
      'opcoesIds': [3],
      'valor': '150.50',
      'dataServico': '2030-01-05',
      'horarioServico': '10:00',
      'duracaoMinutos': 195,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulario de proposta rola com teclado em tela compacta', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/solicitacoes/7/propostas-atendimento') {
          return jsonResponse({
            'paginacao': {'temMais': false},
            'propostas': [],
          });
        }
        if (request.url.path == '/categorias/5/servicos/12/opcoes') {
          return jsonResponse({
            'opcoes': [
              {'id': 3, 'nome': 'Pisos'},
            ],
            'paginacao': {'temMais': false},
          });
        }
        return null;
      },
    );
    final pedido = Solicitacao(
      id: 7,
      clienteId: 1,
      profissionalId: 2,
      categoriaId: 5,
      servicoCatalogoId: 12,
      descricao: 'Teste',
      dataServico: DateTime(2030, 1, 5),
      horarioServico: '10:00',
      precoInicial: 100,
      status: StatusSolicitacao.aguardandoResposta,
      criadoEm: DateTime(2029),
      atualizadoEm: DateTime(2029),
    );
    await abrirFrontend(
      tester,
      '/proposta-compacta',
      width: 320,
      textScale: 2,
      overrides: {
        '/proposta-compacta': (_) => Scaffold(
          body: SingleChildScrollView(
            child: PropostasAtendimentoPanel(
              solicitacao: pedido,
              opcoesSolicitadas: const [
                {'id': 3, 'nome': 'Pisos'},
              ],
              cliente: false,
              profissional: true,
              negociacaoIniciada: true,
            ),
          ),
        ),
      },
    );
    tester.view.physicalSize = const Size(320, 640);
    await tester.ensureVisible(find.text('Criar proposta'));
    await tester.tap(find.text('Criar proposta'));
    await tester.pumpAndSettle();

    final valor = find.widgetWithText(TextFormField, 'Valor em reais');
    await tester.ensureVisible(valor);
    await tester.tap(valor);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(valor, '125');
    final enviar = find.text('Enviar proposta');
    await tester.ensureVisible(enviar);
    expect(enviar.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente confirma a proposta sem pagamento no app', (
    tester,
  ) async {
    var confirmada = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/7/propostas-atendimento') {
          return jsonResponse({
            'paginacao': {'temMais': false},
            'propostas': [
              {
                'id': 22,
                'versao': 1,
                'valor': 150,
                'dataServico': '2030-01-05',
                'horarioServico': '10:00',
                'duracaoMinutos': 120,
                'status': confirmada ? 'aceita' : 'pendente',
                'opcoes': [
                  {'id': 3, 'nome': 'Pisos'},
                ],
              },
            ],
          });
        }
        if (request.url.path ==
            '/solicitacoes/7/propostas-atendimento/22/responder') {
          expect(jsonDecode(request.body), {'aceitar': true});
          confirmada = true;
          return jsonResponse({'status': 'aceita'});
        }
        return null;
      },
    );
    final pedido = Solicitacao(
      id: 7,
      clienteId: 1,
      profissionalId: 2,
      categoriaId: 5,
      descricao: 'Teste',
      dataServico: DateTime(2030, 1, 5),
      horarioServico: '10:00',
      precoInicial: 100,
      status: StatusSolicitacao.aguardandoResposta,
      criadoEm: DateTime(2029),
      atualizadoEm: DateTime(2029),
    );
    await abrirFrontend(
      tester,
      '/proposta-teste',
      width: 320,
      textScale: 2,
      overrides: {
        '/proposta-teste': (_) => Scaffold(
          body: SingleChildScrollView(
            child: PropostasAtendimentoPanel(
              solicitacao: pedido,
              opcoesSolicitadas: const [
                {'id': 3, 'nome': 'Pisos'},
              ],
              cliente: true,
              profissional: false,
              negociacaoIniciada: true,
            ),
          ),
        ),
      },
    );
    final confirmar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar atendimento'),
    );
    expect(confirmar.onPressed, isNotNull);
    final confirmarBotao = find
        .widgetWithText(FilledButton, 'Confirmar atendimento')
        .first;
    await tester.ensureVisible(confirmarBotao);
    await tester.pumpAndSettle();
    await tester.tap(confirmarBotao);
    await tester.pumpAndSettle();
    expect(find.textContaining('não processa'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmar atendimento'),
      ),
    );
    await tester.pumpAndSettle();
    expect(confirmada, isTrue);
    expect(
      find.text('Atendimento confirmado; horário reservado.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
