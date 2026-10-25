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

Future<void> revelar(WidgetTester tester, Finder alvo) async {
  for (
    var tentativa = 0;
    tentativa < 8 && alvo.evaluate().isEmpty;
    tentativa++
  ) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  if (alvo.evaluate().isNotEmpty) await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
}

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

  testWidgets('profissional pode seguir sem documentos e vê o aviso', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/documentos') {
          return jsonResponse({'documentos': [], 'habilitacao': habilitacao()});
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.documentosProfissional);
    expect(find.textContaining('precisa ser habilitado'), findsOneWidget);
    final continuar = find.byKey(const ValueKey('continuar-sem-documentos'));
    await tester.scrollUntilVisible(continuar, 200);
    await tester.pumpAndSettle();
    await tester.tap(continuar);
    await tester.pumpAndSettle();

    expect(find.text('ConectaLar Profissional'), findsWidgets);
    expect(
      find.byKey(const ValueKey('continuar-sem-documentos')),
      findsNothing,
    );
  });

  testWidgets('confirmacao telefonica fica indisponivel enquanto desativada', (
    tester,
  ) async {
    final chamadas = <String>[];
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        chamadas.add(request.url.path);
        if (request.url.path == '/profissionais/me/documentos') {
          return jsonResponse({'documentos': [], 'habilitacao': habilitacao()});
        }
        if (request.url.path == '/profissionais/me/habilitacao/telefone') {
          return jsonResponse({
            'telefone': {
              'estado': 'nao_iniciada',
              'disponivel': false,
              'telefoneMascarado': '+55 (***) *****-4321',
              'tentativasRestantes': null,
              'expiraEm': null,
              'resolvidaEm': null,
            },
          });
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.documentosProfissional);
    final aviso = find.textContaining('WhatsApp ainda');
    await revelar(tester, aviso);
    expect(aviso, findsOneWidget);
    final iniciar = find.byKey(const ValueKey('iniciar-confirmacao-telefone'));
    expect(iniciar, findsNothing);
    expect(chamadas, contains('/profissionais/me/habilitacao/telefone'));
  });

  testWidgets('consentimento, envio e confirmacao telefonica usam a API', (
    tester,
  ) async {
    final corpos = <String, Map<String, dynamic>>{};
    var estadoTelefone = 'nao_iniciada';
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/documentos') {
          return jsonResponse({'documentos': [], 'habilitacao': habilitacao()});
        }
        if (request.url.path == '/profissionais/me/habilitacao/telefone' &&
            request.method == 'GET') {
          return jsonResponse({
            'telefone': {
              'estado': estadoTelefone,
              'disponivel': true,
              'telefoneMascarado': '+55 (***) *****-4321',
              'tentativasRestantes': estadoTelefone == 'pendente' ? 2 : null,
              'expiraEm': null,
              'resolvidaEm': null,
            },
          });
        }
        if (request.url.path == '/profissionais/me/habilitacao/telefone' &&
            request.method == 'POST') {
          corpos['inicio'] = jsonDecode(request.body) as Map<String, dynamic>;
          estadoTelefone = 'pendente';
          return jsonResponse({
            'telefone': {
              'estado': estadoTelefone,
              'disponivel': true,
              'telefoneMascarado': '+55 (***) *****-4321',
              'tentativasRestantes': 3,
              'expiraEm': '2026-10-25T23:00:00.000Z',
              'resolvidaEm': null,
            },
          }, 201);
        }
        if (request.url.path ==
            '/profissionais/me/habilitacao/telefone/confirmacao') {
          corpos['confirmacao'] =
              jsonDecode(request.body) as Map<String, dynamic>;
          estadoTelefone = 'confirmada';
          return jsonResponse({
            'telefone': {
              'estado': estadoTelefone,
              'disponivel': true,
              'telefoneMascarado': '+55 (***) *****-4321',
              'tentativasRestantes': null,
              'expiraEm': '2026-10-25T23:00:00.000Z',
              'resolvidaEm': '2026-10-25T22:50:00.000Z',
            },
          });
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.documentosProfissional);
    final iniciar = find.byKey(const ValueKey('iniciar-confirmacao-telefone'));
    await revelar(tester, iniciar);
    await tester.tap(iniciar);
    await tester.pumpAndSettle();
    final consentir = find.byKey(
      const ValueKey('confirmar-consentimento-telefone'),
    );
    expect(consentir, findsOneWidget);
    expect(tester.widget<FilledButton>(consentir).onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey('consentimento-confirmacao-telefone')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(consentir).onPressed, isNotNull);
    await tester.tap(consentir);
    await tester.pumpAndSettle();
    expect(corpos['inicio'], {'consentimento': true});

    final informar = find.byKey(const ValueKey('informar-codigo-telefone'));
    await revelar(tester, informar);
    await tester.tap(informar);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('codigo-confirmacao-telefone')),
      '123456',
    );
    await tester.tap(
      find.byKey(const ValueKey('enviar-codigo-confirmacao-telefone')),
    );
    await tester.pumpAndSettle();

    expect(corpos['confirmacao']?['codigo'], '123456');
    expect(
      corpos['confirmacao']?['tentativaId'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    final confirmado = find.text('Acesso ao telefone confirmado.');
    await revelar(tester, confirmado);
    expect(confirmado, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retoma a mesma tentativa idempotente apos erro de conexao', (
    tester,
  ) async {
    const tentativaExistente = '123e4567-e89b-42d3-a456-426614174000';
    final tentativasEnviadas = <String>[];
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path == '/profissionais/me/documentos') {
          return jsonResponse({'documentos': [], 'habilitacao': habilitacao()});
        }
        if (request.url.path == '/profissionais/me/habilitacao/telefone' &&
            request.method == 'GET') {
          return jsonResponse({
            'telefone': {
              'estado': 'pendente',
              'disponivel': true,
              'tentativaId': tentativaExistente,
              'telefoneMascarado': '+55 (***) *****-4321',
              'tentativasRestantes': 2,
              'expiraEm': '2026-10-25T23:00:00.000Z',
              'resolvidaEm': null,
            },
          });
        }
        if (request.url.path ==
            '/profissionais/me/habilitacao/telefone/confirmacao') {
          final corpo = jsonDecode(request.body) as Map<String, dynamic>;
          tentativasEnviadas.add(corpo['tentativaId'] as String);
          if (tentativasEnviadas.length == 1) {
            return jsonResponse({
              'message': 'Falha temporaria de conexao.',
            }, 503);
          }
          return jsonResponse({
            'telefone': {
              'estado': 'confirmada',
              'disponivel': true,
              'tentativaId': null,
              'telefoneMascarado': '+55 (***) *****-4321',
              'tentativasRestantes': null,
              'expiraEm': '2026-10-25T23:00:00.000Z',
              'resolvidaEm': '2026-10-25T22:50:00.000Z',
            },
          });
        }
        return null;
      },
    );

    await abrirFrontend(tester, AppRoutes.documentosProfissional);
    final informar = find.byKey(const ValueKey('informar-codigo-telefone'));
    await revelar(tester, informar);

    Future<void> enviarCodigo() async {
      await tester.tap(informar);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('codigo-confirmacao-telefone')),
        '123456',
      );
      await tester.tap(
        find.byKey(const ValueKey('enviar-codigo-confirmacao-telefone')),
      );
      await tester.pumpAndSettle();
    }

    await enviarCodigo();
    await enviarCodigo();
    expect(tentativasEnviadas, [tentativaExistente, tentativaExistente]);
    expect(tester.takeException(), isNull);
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
      final botao = find.byKey(const Key('solicitar-revisao-habilitacao'));
      await tester.scrollUntilVisible(botao, 200);
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(chamadas, 1);
      expect(find.text('Solicitação de revisão registrada.'), findsOneWidget);
      await tester.scrollUntilVisible(botao, 200);
      expect(tester.widget<OutlinedButton>(botao).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('Habilitação pendente'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
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
