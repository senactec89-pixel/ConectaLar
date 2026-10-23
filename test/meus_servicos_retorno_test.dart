import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('meus serviços recarrega status ao retornar e preserva filtro', (
    tester,
  ) async {
    var consultas = 0;
    var concluido = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me') {
          consultas++;
          return jsonResponse({
            'solicitacoes': [
              {
                ...FrontendPreviewClient().pedidos.first,
                'status': concluido
                    ? 'conclusao_confirmada'
                    : 'aceita_agendada',
                'avaliado': concluido,
              },
            ],
          });
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.meusServicos,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              concluido = true;
              Navigator.pop(context);
            },
            child: const Text('Retornar à lista'),
          ),
        ),
      },
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('servicos-filtro-agendados')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('servicos-filtro-agendados')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalhes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retornar à lista'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('servicos-filtro-agendados')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Ver detalhes'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('servicos-filtro-todos')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('servicos-filtro-todos')));
    await tester.pumpAndSettle();
    expect(find.text('Conclusão confirmada'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meus serviços permite retry se recarga no retorno falha', (
    tester,
  ) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me' && ++consultas == 2) {
          return jsonResponse({'message': 'Falha'}, 503);
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.meusServicos,
      overrides: {
        AppRoutes.detalhesServico: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retornar à lista'),
          ),
        ),
      },
    );
    await tester.tap(find.text('Ver detalhes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retornar à lista'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(consultas, 3);
    expect(find.text('Ver detalhes'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meus serviços atualiza ao puxar a lista', (tester) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/solicitacoes/me') {
          consultas++;
          return null;
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.meusServicos);
    expect(consultas, 1);

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(consultas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista vazia orienta a buscar ou ver todos os pedidos', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/solicitacoes/me'
          ? jsonResponse({'solicitacoes': []})
          : null,
    );
    await abrirFrontend(
      tester,
      AppRoutes.meusServicos,
      width: 360,
      textScale: 2,
      overrides: {
        AppRoutes.busca: (_) => const Scaffold(body: Text('Busca aberta')),
      },
    );

    expect(find.text('Você ainda não tem solicitações'), findsOneWidget);
    final buscar = find.text('Buscar profissionais');
    await tester.scrollUntilVisible(
      buscar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(buscar);
    await tester.pumpAndSettle();
    expect(find.text('Busca aberta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro sem resultados permite voltar para todos os pedidos', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/solicitacoes/me'
          ? jsonResponse({'solicitacoes': []})
          : null,
    );
    await abrirFrontend(tester, AppRoutes.meusServicos);
    final aguardando = find.byKey(const ValueKey('servicos-filtro-aguardando'));
    await tester.ensureVisible(aguardando);
    await tester.tap(aguardando);
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhuma solicitação aguardando resposta'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ver todos os pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Você ainda não tem solicitações'), findsOneWidget);
    expect(find.text('Buscar profissionais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meus serviços carrega páginas seguintes sem repetir pedidos', (
    tester,
  ) async {
    final paginasConsultadas = <String?>[];
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path != '/solicitacoes/me') return null;
        final pagina = request.url.queryParameters['pagina'] ?? '1';
        paginasConsultadas.add(pagina);
        final id = pagina == '1' ? 1001 : 2002;
        return jsonResponse({
          'paginacao': {
            'pagina': int.parse(pagina),
            'limite': 20,
            'total': 2,
            'totalPaginas': 2,
            'temMais': pagina == '1',
          },
          'solicitacoes': [
            {...FrontendPreviewClient().pedidos.first, 'id': id},
          ],
        });
      },
    );
    await abrirFrontend(tester, AppRoutes.meusServicos);
    final carregar = find.byKey(const ValueKey('servicos-carregar-mais'));
    await tester.scrollUntilVisible(
      carregar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(carregar);
    await tester.pumpAndSettle();

    expect(paginasConsultadas, ['1', '2']);
    expect(find.byKey(const ValueKey('servico-1001')), findsOneWidget);
    expect(find.byKey(const ValueKey('servico-2002')), findsOneWidget);
    expect(find.byKey(const ValueKey('servicos-carregar-mais')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
