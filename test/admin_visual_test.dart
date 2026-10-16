import 'dart:convert';

import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/admin/admin_pages.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/services/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _sessaoAdministrativa() async {
  SharedPreferences.setMockInitialValues({});
  AppServices.instance = AppServices(
    sessionStorage: MemorySessionStorage(),
    api: ApiService(
      client: MockClient((request) async {
        final data = switch (request.url.path) {
          '/auth/login' => {
            'token': {'accessToken': 'token-exclusivo-de-teste'},
            'usuario': {
              'id': 99,
              'nome': 'Administrador de teste',
              'tipo': 'administrador',
            },
          },
          '/admin/painel' => {
            'usuarios': {'ativos': 12, 'profissionais': 5},
            'profissionais': {'perfisAtivos': 5},
            'moderacao': {
              'documentosPendentes': 2,
              'denunciasAbertas': 1,
              'avaliacoesPendentes': 3,
            },
            'catalogo': {'categoriasAtivas': 8},
            'atendimentos': {'aguardandoResposta': 4, 'aceitaAgendada': 2},
          },
          '/admin/usuarios' => {
            'usuarios': [
              {
                'id': 7,
                'nome': 'Profissional com nome completo de teste',
                'email': 'teste@example.invalid',
                'tipo': 'profissional',
                'ativo': true,
              },
            ],
          },
          '/documentos-verificacao' => {
            'documentos': [
              {
                'id': 7,
                'tipoDocumento': 'documento_identidade',
                'profissional': {'nome': 'Profissional de teste'},
                'status': 'pendente',
                'nomeArquivo': 'documento-de-identidade-para-verificacao.pdf',
              },
            ],
          },
          '/denuncias/moderacao' => {
            'denuncias': [
              {
                'id': 7,
                'motivo': 'Problema no atendimento',
                'status': 'aberta',
                'descricao':
                    'Relato de teste para verificar a apresentação do conteúdo.',
                'solicitacaoId': 5,
              },
            ],
          },
          '/avaliacoes/moderacao' => {
            'avaliacoes': [
              {
                'id': 7,
                'nota': 4,
                'avaliador': {'nome': 'Cliente de teste'},
                'avaliado': {'nome': 'Profissional de teste'},
                'comentario':
                    'Comentário de avaliação usado apenas neste teste.',
              },
            ],
          },
          '/categorias/admin' => {
            'categorias': [
              {'id': 7, 'nome': 'Manutenção residencial', 'ativo': true},
            ],
          },
          '/admin/painel/auditoria' => {
            'eventos': [
              {
                'id': 7,
                'acao': 'documento_analisado',
                'ator': {
                  'nome': 'Administrador de teste',
                  'tipo': 'administrador',
                },
                'alvoTipo': 'documento_verificacao',
                'alvoId': 8,
                'detalhe': 'Registro de teste para conferência visual.',
                'criadoEm': '2026-10-11T12:00:00Z',
              },
            ],
          },
          _ => <String, dynamic>{},
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ),
  );
  await AppServices.instance.auth.login(
    email: 'teste@example.invalid',
    senha: 'Senha-de-teste',
  );
}

Future<void> _abrir(
  WidgetTester tester,
  AdminModulo modulo,
  double width,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey('$modulo-$width'),
      theme: AppTheme.light,
      home: AdminPage(modulo: modulo),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(_sessaoAdministrativa);
  tearDown(() => AppServices.instance.api.close());

  for (final modulo in AdminModulo.values) {
    testWidgets('admin $modulo com conteúdo em 360, 390 e 412 px', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [360.0, 390.0, 412.0]) {
        await _abrir(tester, modulo, width);
        expect(find.text('Acesso restrito'), findsNothing);
        expect(find.byType(Card), findsWidgets);
        expect(tester.takeException(), isNull, reason: '$modulo em $width px');
      }
    });
  }

  testWidgets('busca administrativa continua utilizável com teclado aberto', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _abrir(tester, AdminModulo.usuarios, 360);
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Buscar nome ou e-mail'), findsOneWidget);
  });
}
