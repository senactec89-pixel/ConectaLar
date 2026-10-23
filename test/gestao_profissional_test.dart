import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('início profissional não mostra voltar para outra área', (
    tester,
  ) async {
    await configurarFrontend(papel: 'profissional');
    await abrirFrontend(tester, AppRoutes.areaProfissional);

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.areaProfissional);
    await tester.pumpAndSettle();

    expect(find.text('ConectaLar Profissional'), findsWidgets);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('profissional pausa oferta preservando seus dados', (
    tester,
  ) async {
    Map<String, dynamic>? salvo;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/servicos' &&
            request.method == 'GET') {
          return jsonResponse({
            'servicos': [_oferta(ativo: true)],
          });
        }
        if (request.url.path == '/profissionais/me/servicos' &&
            request.method == 'PUT') {
          salvo = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({'servicos': salvo!['servicos']});
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.servicosProfissional);
    await tester.tap(find.byTooltip('Ações da oferta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pausar'));
    await tester.pumpAndSettle();

    final ofertas = salvo!['servicos'] as List<dynamic>;
    final oferta = ofertas.single as Map<String, dynamic>;
    expect(oferta['id'], 7);
    expect(oferta['nome'], 'Instalação elétrica');
    expect(oferta['ativo'], isFalse);
    expect(oferta['duracaoMinutos'], 90);
    expect(oferta['intervaloMinutos'], 30);
    expect(find.textContaining('Pausada'), findsOneWidget);
  });

  testWidgets('erro ao salvar mantém formulário e valores preenchidos', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/categorias') {
          return jsonResponse({
            'categorias': [
              {'id': 2, 'nome': 'Elétrica'},
            ],
          });
        }
        if (request.url.path == '/profissionais/me/servicos' &&
            request.method == 'GET') {
          return jsonResponse({'servicos': []});
        }
        if (request.url.path == '/profissionais/me/servicos' &&
            request.method == 'PUT') {
          return jsonResponse({
            'message': 'Não foi possível salvar esta oferta agora.',
          }, 503);
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.servicosProfissional);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Adicionar serviço'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do serviço'),
      'Troca de tomada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Preço inicial (R\$)'),
      '80',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar serviço'), findsNWidgets(2));
    expect(find.text('Troca de tomada'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(
      find.text('Não foi possível salvar esta oferta agora.'),
      findsOneWidget,
    );
  });

  testWidgets('cadastro mostra progresso real e acesso ao perfil público', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me') {
          return jsonResponse({
            'profissional': {
              'id': 9,
              'usuarioId': 3,
              'nome': 'Profissional Teste',
              'descricao': 'Manutenção residencial',
              'bairro': 'Centro',
              'cidade': 'São Paulo',
              'uf': 'SP',
              'raioAtendimentoKm': 15,
              'verificado': true,
              'podeReceberSolicitacoes': true,
              'servicos': [_oferta(ativo: true)],
            },
          });
        }
        if (request.url.path == '/profissionais/me/servicos') {
          return jsonResponse({
            'servicos': [_oferta(ativo: true)],
          });
        }
        if (request.url.path == '/profissionais/me/disponibilidade') {
          return jsonResponse({
            'disponibilidades': [
              {
                'diaSemana': 1,
                'horaInicio': '08:00',
                'horaFim': '17:00',
                'ativo': true,
              },
            ],
          });
        }
        if (request.url.path == '/profissionais/me/documentos') {
          return jsonResponse({
            'documentos': [
              {
                'id': 4,
                'tipoDocumento': 'documento_identidade',
                'referenciaArquivo': 'privado/4',
                'nomeArquivo': 'identidade.pdf',
                'status': 'aprovado',
                'motivoRejeicao': null,
                'analisadoEm': '2026-10-18T14:00:00Z',
                'criadoEm': '2026-10-18T12:00:00Z',
              },
            ],
            'habilitacao': {..._habilitacao(), 'podeAtender': true},
          });
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.cadastroProfissional);
    expect(find.text('Disponibilidade'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('checklist-cadastro-profissional')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('5 de 5 itens básicos concluídos'), findsOneWidget);
    expect(find.text('Ver meu perfil público'), findsOneWidget);
    expect(
      find.textContaining('Seu perfil pode receber solicitações'),
      findsOneWidget,
    );
  });

  testWidgets('atualização manual mostra rejeição e próxima ação', (
    tester,
  ) async {
    var consultas = 0;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/documentos') {
          consultas++;
          return jsonResponse({
            'documentos': [
              {
                'id': 10,
                'tipoDocumento': 'documento_identidade',
                'referenciaArquivo': 'privado/10',
                'nomeArquivo': 'identidade.pdf',
                'observacao': null,
                'status': consultas == 1 ? 'pendente' : 'rejeitado',
                'motivoRejeicao': consultas == 1
                    ? null
                    : 'A imagem está ilegível.',
                'analisadoEm': consultas == 1
                    ? null
                    : '2026-10-18T14:00:00.000Z',
                'criadoEm': '2026-10-18T12:00:00.000Z',
              },
            ],
            'habilitacao': _habilitacao(),
          });
        }
        if (request.url.path == '/profissionais/me/habilitacao/identidade') {
          return jsonResponse({
            'identidade': {
              'estado': 'nao_iniciada',
              'disponivel': false,
              'url': null,
              'expiraEm': null,
              'resolvidaEm': null,
            },
          });
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.documentosProfissional);
    expect(find.text('Documento em análise'), findsOneWidget);
    final atualizar = find.byKey(
      const ValueKey('atualizar-situacao-documental'),
    );
    await tester.scrollUntilVisible(atualizar, 400);
    await tester.ensureVisible(atualizar);
    await tester.pumpAndSettle();
    await tester.tap(atualizar);
    await tester.pumpAndSettle();

    expect(find.text('Documento precisa ser reenviado'), findsOneWidget);
    expect(find.textContaining('A imagem está ilegível.'), findsWidgets);
    expect(find.text('Reenviar documento'), findsOneWidget);
  });

  testWidgets('avaliações aplicam filtros e navegam entre páginas', (
    tester,
  ) async {
    final consultas = <Uri>[];
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path != '/profissionais/me/avaliacoes') return null;
        consultas.add(request.url);
        final pagina =
            int.tryParse(request.url.queryParameters['pagina'] ?? '') ?? 1;
        return jsonResponse({
          'resumo': {'notaMedia': 4.5, 'quantidadeAvaliacoes': 12},
          'paginacao': {
            'pagina': pagina,
            'limite': 10,
            'total': 12,
            'totalPaginas': 2,
          },
          'avaliacoes': [
            {
              'id': pagina,
              'nota': 5,
              'comentario': 'Página $pagina',
              'criadoEm': '2026-10-18T12:00:00Z',
            },
          ],
        });
      },
    );

    await abrirFrontend(tester, AppRoutes.avaliacoesRecebidas);
    await tester.tap(find.text('Todas as notas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 estrelas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Com comentário'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próxima página'));
    await tester.pumpAndSettle();

    expect(consultas.last.queryParameters['pagina'], '2');
    expect(consultas.last.queryParameters['nota'], '5');
    expect(consultas.last.queryParameters['comComentario'], 'true');
    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(find.text('Página 2'), findsOneWidget);
  });

  testWidgets('detalhe profissional unifica conversa e denúncia', (
    tester,
  ) async {
    final previa = FrontendPreviewClient(papel: 'profissional');
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async => request.url.path == '/solicitacoes/1001'
          ? jsonResponse({'solicitacao': previa.pedidos.first})
          : null,
    );

    await abrirFrontend(
      tester,
      AppRoutes.detalhesSolicitacaoProfissional,
      arguments: 1001,
    );

    expect(find.text('Aceitar solicitação'), findsOneWidget);
    expect(find.text('Conversar'), findsOneWidget);
    final denunciar = find.byKey(const ValueKey('detalhes-denunciar'));
    await tester.scrollUntilVisible(
      denunciar,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(denunciar, findsOneWidget);
  });
}

Map<String, dynamic> _oferta({required bool ativo}) => {
  'id': 7,
  'nome': 'Instalação elétrica',
  'categoriaId': 2,
  'categoria': {'id': 2, 'nome': 'Elétrica'},
  'precoInicial': 120,
  'ativo': ativo,
  'duracaoMinutos': 90,
  'intervaloMinutos': 30,
};

Map<String, dynamic> _habilitacao() => {
  'estado': 'pendente',
  'podeAtender': false,
  'documentoAnalisado': false,
  'revisaoSolicitadaEm': null,
  'etapas': [
    {'codigo': 'email', 'status': 'confirmado'},
    {'codigo': 'telefone', 'status': 'aguardando_integracao'},
    {'codigo': 'identidade', 'status': 'aguardando_integracao'},
    {'codigo': 'antecedentes', 'status': 'aguardando_politica'},
    {'codigo': 'aprovacao', 'status': 'pendente'},
  ],
};
