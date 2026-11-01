import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('situação da denúncia é clara com texto ampliado', (
    tester,
  ) async {
    var status = 'rejeitada';
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path != '/denuncias/me') return null;
        return jsonResponse({
          'denuncias': [
            {
              'id': 1,
              'solicitacaoId': 1001,
              'atendimento': {
                'id': 1001,
                'nomeServico': 'Instalação elétrica residencial completa',
              },
              'motivo': 'Conduta inadequada',
              'descricao': 'Relato de demonstração.',
              'status': status,
            },
          ],
        });
      },
    );
    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 2.0]) {
        for (final situacao in ['rejeitada', 'em_analise', 'desconhecida']) {
          status = situacao;
          await tester.pumpWidget(const SizedBox.shrink());
          await abrirFrontend(
            tester,
            AppRoutes.minhasDenuncias,
            width: largura,
            textScale: escala,
          );
          expect(find.text('Data de envio indisponível'), findsOneWidget);
          final texto = switch (situacao) {
            'rejeitada' =>
              'A análise foi encerrada. Nenhum detalhe da decisão foi informado.',
            'em_analise' =>
              'A equipe está analisando o relato. Atualize esta tela para acompanhar.',
            _ => 'A situação da denúncia está indisponível no momento.',
          };
          expect(find.text(texto), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '$largura px, $escala×, $status',
          );
        }
      }
    }
  });

  testWidgets('falha ao atualizar denúncias oferece nova tentativa', (
    tester,
  ) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path != '/denuncias/me') return null;
        consultas++;
        return consultas == 2
            ? jsonResponse({'message': 'Falha'}, 503)
            : jsonResponse({'denuncias': []});
      },
    );
    await abrirFrontend(tester, AppRoutes.minhasDenuncias);
    await tester.tap(find.byTooltip('Atualizar denúncias'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar suas denúncias.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma denúncia enviada'), findsOneWidget);
    expect(consultas, 3);
    expect(tester.takeException(), isNull);
  });
}
