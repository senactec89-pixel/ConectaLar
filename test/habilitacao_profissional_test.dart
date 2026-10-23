import 'dart:convert';
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/api_mappers.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/frontend_helpers.dart';

Map<String, dynamic> habilitacao({bool revisao = false}) => {
  'estado': 'pendente',
  'podeAtender': false,
  'documentoAnalisado': true,
  'revisaoSolicitadaEm': revisao ? '2026-10-18T12:00:00Z' : null,
  'etapas': [
    {'codigo': 'email', 'status': 'confirmado'},
    {'codigo': 'telefone', 'status': 'aguardando_integracao'},
    {'codigo': 'identidade', 'status': 'aguardando_integracao'},
    {'codigo': 'antecedentes', 'status': 'aguardando_politica'},
    {'codigo': 'aprovacao', 'status': 'pendente'},
  ],
};

void main() {
  tearDown(() => AppServices.instance.api.close());

  test('selo legado e campo ausente nao habilitam solicitacoes', () {
    final perfil = profissionalFromApi({
      'id': 1,
      'usuarioId': 2,
      'nome': 'Teste',
      'descricao': 'Teste',
      'bairro': 'Centro',
      'verificado': true,
    });
    expect(perfil.verificado, isTrue);
    expect(perfil.podeReceberSolicitacoes, isFalse);
  });

  testWidgets(
    'profissional solicita revisao sem enviar identidade e sem liberar atendimento',
    (tester) async {
      var solicitada = false;
      var chamadas = 0;
      await configurarFrontend(
        papel: 'profissional',
        responder: (request) async {
          if (request.url.path == '/profissionais/me/documentos') {
            return jsonResponse({
              'documentos': [],
              'habilitacao': habilitacao(revisao: solicitada),
            });
          }
          if (request.url.path == '/profissionais/me/habilitacao/revisao') {
            expect(jsonDecode(request.body), isEmpty);
            chamadas++;
            solicitada = true;
            return jsonResponse({
              'habilitacao': habilitacao(revisao: true),
            }, 201);
          }
          return null;
        },
      );
      await abrirFrontend(tester, AppRoutes.documentosProfissional);
      expect(find.text('Habilitação pendente'), findsOneWidget);
      final botao = find.byKey(
        const Key('solicitar-revisao-habilitacao'),
      );
      await tester.scrollUntilVisible(botao, 200);
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(chamadas, 1);
      expect(find.text('Solicitação de revisão registrada.'), findsOneWidget);
      await tester.scrollUntilVisible(botao, 200);
      expect(tester.widget<OutlinedButton>(botao).onPressed, isNull);
      expect(find.text('Habilitação pendente'), findsOneWidget);
    },
  );

  testWidgets('admin recebe erro de MFA com nova tentativa', (tester) async {
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path == '/admin/profissionais/habilitacoes') {
          return jsonResponse({
            'message': 'Ative a verificação em duas etapas.',
          }, 403);
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminHabilitacoes);
    expect(find.text('Ative a verificação em duas etapas.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets(
    'admin organiza revisao sem aprovar em telas estreitas e texto ampliado',
    (tester) async {
      final chamadas = <Map<String, dynamic>>[];
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path == '/admin/profissionais/habilitacoes') {
            return jsonResponse({
              'pagina': 1,
              'total': 1,
              'profissionais': [
                {
                  'id': 10,
                  'nome': 'Profissional de teste',
                  'habilitacao': habilitacao(),
                },
              ],
            });
          }
          if (request.url.path == '/admin/profissionais/10/habilitacao') {
            chamadas.add(jsonDecode(request.body) as Map<String, dynamic>);
            return jsonResponse({'habilitacao': habilitacao()});
          }
          return null;
        },
      );
      for (final largura in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.adminHabilitacoes,
          width: largura,
          textScale: 2,
        );
        await tester.tap(find.text('Profissional de teste'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmar'), findsOneWidget);
        expect(find.text('Aprovar'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(chamadas.last, {
          'acao': 'iniciar_analise',
          'motivo': 'revisao_cadastral',
        });
        expect(tester.takeException(), isNull);
      }
    },
  );
}
