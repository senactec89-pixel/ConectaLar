import 'dart:convert';

import 'package:conectarlar_app/app/app.dart';
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/services/api_mappers.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _perfil = <String, dynamic>{
  'id': 7,
  'usuarioId': 20,
  'nome': 'Profissional real',
  'descricao': 'Manutenção elétrica residencial com atendimento agendado.',
  'bairro': 'Centro',
  'precoInicial': 80.5,
  'notaMedia': 4.5,
  'quantidadeAvaliacoes': 2,
  'servicos': [
    {
      'id': 31,
      'nome': 'Instalação',
      'categoriaId': 1,
      'categoria': {'id': 1, 'nome': 'Elétrica'},
      'precoInicial': 80,
    },
    {
      'id': 32,
      'nome': 'Reparo',
      'categoriaId': 2,
      'categoria': {'id': 2, 'nome': 'Manutenção'},
      'precoInicial': 125.5,
    },
  ],
};

Map<String, dynamic> _pedido({
  String status = 'aguardando_resposta',
  bool avaliado = false,
}) => {
  'id': 45,
  'servicoId': 32,
  'nomeServico': 'Reparo',
  'cliente': {'id': 10, 'nome': 'Cliente real'},
  'profissional': {'id': 7, 'usuarioId': 20, 'nome': 'Profissional real'},
  'categoria': {'id': 2, 'nome': 'Manutenção'},
  'status': status,
  'avaliado': avaliado,
  'descricao': 'Reparar a instalação elétrica da residência.',
  'bairroAtendimento': 'Centro',
  'dataServico': '2027-10-15',
  'horarioServico': '10:00',
  'precoInicial': 125.5,
};

http.Response _json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _sessao(
  String tipo,
  Future<http.Response> Function(http.Request) handler,
) async {
  SharedPreferences.setMockInitialValues({});
  AppServices.instance = AppServices(
    api: ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _json({
            'token': {'accessToken': 'token-teste'},
            'usuario': {
              'id': tipo == 'cliente' ? 10 : 20,
              'tipo': tipo,
              'nome': 'Conta $tipo',
              'email': '$tipo@teste.local',
            },
          });
        }
        return handler(request);
      }),
    ),
  );
  await AppServices.instance.auth.login(
    email: '$tipo@teste.local',
    senha: 'Teste123!',
  );
}

Future<void> _abrir(
  WidgetTester tester,
  String route, {
  Object? arguments,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey(route),
      theme: AppTheme.light,
      routes: AppRoutes.routes,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      initialRoute: route,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: route, arguments: arguments),
          builder: AppRoutes.routes[route]!,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'API indisponível não insere profissionais fictícios em Home ou busca',
    (tester) async {
      AppServices.instance = AppServices(
        api: ApiService(
          client: MockClient(
            (_) async => _json({'message': 'Indisponível'}, 503),
          ),
        ),
      );
      await _abrir(tester, AppRoutes.home);
      expect(find.text('Carlos Silva'), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _abrir(tester, AppRoutes.busca);
      expect(find.text('Carlos Silva'), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _abrir(tester, AppRoutes.meusServicos);
      expect(find.text('Entre na sua conta para continuar.'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets('dados de demonstração exigem ativação e exibem identificação', (
    tester,
  ) async {
    AppServices.instance = AppServices(modoDemo: true);
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();
    expect(find.text('Carlos Silva'), findsOneWidget);
    expect(tester.widget<Banner>(find.byType(Banner)).message, 'DEMONSTRAÇÃO');
  });

  testWidgets(
    'cliente e profissional recebem somente suas ações nos detalhes',
    (tester) async {
      for (final tipo in ['cliente', 'profissional']) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _sessao(tipo, (_) async => _json({'solicitacao': _pedido()}));
        await _abrir(tester, AppRoutes.detalhesServico, arguments: 45);
        await tester.scrollUntilVisible(
          find.text('Ações do fluxo'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Aceitar solicitação'),
          tipo == 'profissional' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Recusar'),
          tipo == 'profissional' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Cancelar'),
          tipo == 'cliente' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'profissional avalia o cliente e a avaliação enviada não pode ser repetida',
    (tester) async {
      final paths = <String>[];
      await _sessao('profissional', (request) async {
        paths.add('${request.method} ${request.url.path}');
        return request.method == 'POST'
            ? _json({
                'avaliacao': {'id': 1},
              })
            : _json({'solicitacao': _pedido(status: 'conclusao_confirmada')});
      });
      await _abrir(tester, AppRoutes.detalhesServico, arguments: 45);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('avaliacao-enviar')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Avaliar cliente'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('avaliacao-enviar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avaliacao-enviar')));
      await tester.pumpAndSettle();
      expect(
        paths.any(
          (path) => path.endsWith('/solicitacoes/45/avaliacoes/cliente'),
        ),
        isTrue,
      );
      expect(find.byKey(const ValueKey('avaliacao-enviar')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await _sessao(
        'profissional',
        (_) async => _json({
          'solicitacao': _pedido(
            status: 'conclusao_confirmada',
            avaliado: true,
          ),
        }),
      );
      await _abrir(tester, AppRoutes.detalhesServico, arguments: 45);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Avaliado'), findsOneWidget);
      expect(find.byKey(const ValueKey('avaliacao-enviar')), findsNothing);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'contas profissional e admin abrem configurações e fazem logout sem consultar clientes',
    (tester) async {
      for (final tipo in ['profissional', 'administrador']) {
        await tester.pumpWidget(const SizedBox.shrink());
        final paths = <String>[];
        await _sessao(tipo, (request) async {
          paths.add('${request.method} ${request.url.path}');
          return _json({'ok': true});
        });
        await _abrir(tester, AppRoutes.perfil);
        expect(find.text('Conta $tipo'), findsOneWidget);
        expect(find.text('Endereço de atendimento'), findsNothing);
        expect(paths, isEmpty);
        await tester.scrollUntilVisible(
          find.text('Sair da conta'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sair da conta'));
        await tester.pumpAndSettle();
        expect(paths.any((path) => path.endsWith('/auth/logout')), isTrue);
        expect(AppServices.instance.auth.autenticado, isFalse);
        expect(paths.any((path) => path.contains('/clientes/')), isFalse);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'edição profissional preenche dados, envia preço numérico e mantém IDs das ofertas',
    (tester) async {
      Map<String, dynamic>? enviado;
      await _sessao('profissional', (request) async {
        if (request.url.path.endsWith('/solicitacoes/me')) {
          return _json({'solicitacoes': []});
        }
        if (request.method == 'PUT') {
          enviado = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return _json({'profissional': _perfil});
      });
      await _abrir(tester, AppRoutes.cadastroProfissional);
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller!.text, _perfil['descricao']);
      expect(fields[1].controller!.text, 'Centro');
      expect(fields[2].controller!.text, '80,5');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profissional-continuar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profissional-continuar')));
      await tester.pumpAndSettle();
      expect(enviado?['precoInicial'], 80.5);
      expect((enviado?['servicos'] as List).map((s) => s['id']), [31, 32]);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'solicitação envia a segunda oferta escolhida com sua categoria',
    (tester) async {
      Map<String, dynamic>? enviado;
      await _sessao('cliente', (request) async {
        if (request.method == 'POST') {
          enviado = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'solicitacao': _pedido()});
        }
        if (request.url.path.endsWith('/clientes/me/enderecos')) {
          return _json({
            'enderecos': [
              {
                'id': 90,
                'apelido': 'Casa',
                'logradouro': 'Rua Um',
                'numero': '123',
                'bairro': 'Centro',
                'cidade': 'Belo Horizonte',
                'uf': 'MG',
                'principal': true,
              },
            ],
          });
        }
        return _json({'disponibilidades': []});
      });
      await _abrir(
        tester,
        AppRoutes.solicitarServico,
        arguments: profissionalFromApi(_perfil),
      );
      await tester.tap(find.byKey(const ValueKey('solicitar-servico')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reparo').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('solicitar-data')),
        '15/10/2027',
      );
      await tester.enterText(
        find.byKey(const ValueKey('solicitar-horario')),
        '10:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('solicitar-descricao')),
        'Reparar a instalação elétrica da residência.',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('solicitar-enviar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('solicitar-enviar')));
      await tester.pumpAndSettle();
      expect(enviado?['servicoId'], 32);
      expect(enviado?['categoriaId'], 2);
      expect(enviado?['enderecoId'], 90);
      expect(find.text('Solicitação enviada'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  test(
    'preço opcional valida decimal, valores negativos e limite do banco',
    () {
      expect(parsePrecoInicial('125,50'), 125.5);
      expect(
        solicitacaoFromApi({..._pedido(), 'precoInicial': null}).precoInicial,
        isNull,
      );
      expect(solicitacaoFromApi(_pedido()).precoInicial, 125.5);
      expect(validarPrecoOpcional(''), isNull);
      for (final valor in ['-1', 'NaN', 'Infinity', 'abc', '100000000']) {
        expect(validarPrecoOpcional(valor), isNotNull);
      }
    },
  );

  testWidgets(
    'Salvar e continuar abre serviços e categorias são selecionadas pelo nome',
    (tester) async {
      Map<String, dynamic>? ofertaEnviada;
      await _sessao('profissional', (request) async {
        final path = request.url.path;
        if (path.endsWith('/profissionais/me')) {
          return _json({
            'profissional': request.method == 'PUT' ? _perfil : null,
          });
        }
        if (path.endsWith('/profissionais/me/servicos')) {
          if (request.method == 'PUT') {
            ofertaEnviada = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return _json({'servicos': []});
        }
        if (path.endsWith('/categorias')) {
          return _json({
            'categorias': [
              {'id': 2, 'nome': 'Manutenção', 'ativo': true},
            ],
          });
        }
        return _json({'solicitacoes': []});
      });
      await _abrir(tester, AppRoutes.cadastroProfissional);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Serviços residenciais com agendamento e cuidado.',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Centro');
      await tester.ensureVisible(
        find.byKey(const ValueKey('profissional-continuar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profissional-continuar')));
      await tester.pumpAndSettle();
      expect(find.text('Meus serviços'), findsOneWidget);
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Reparo');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manutenção').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '-1');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Informe um valor entre 0 e 99.999.999,99.'),
        findsOneWidget,
      );
      expect(ofertaEnviada, isNull);
      await tester.enterText(find.byType(TextFormField).at(1), '125,50');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final oferta = (ofertaEnviada?['servicos'] as List).single;
      expect(oferta['categoriaId'], 2);
      expect(oferta['precoInicial'], 125.5);
    },
  );

  testWidgets(
    'avaliações recebidas mostram média e lista em 360, 390 e 412 com texto ampliado',
    (tester) async {
      await _sessao(
        'profissional',
        (_) async => _json({
          'resumo': {'notaMedia': 4.5, 'quantidadeAvaliacoes': 2},
          'avaliacoes': [
            {
              'id': 1,
              'nota': 5,
              'comentario':
                  'Atendimento cuidadoso e pontual, conforme combinado.',
              'criadoEm': '2026-10-11T10:00:00Z',
            },
          ],
        }),
      );
      for (final width in [360.0, 390.0, 412.0]) {
        await _abrir(
          tester,
          AppRoutes.avaliacoesRecebidas,
          width: width,
          scale: 1.6,
        );
        expect(find.text('4,5 ★ • 2 avaliações'), findsOneWidget);
        expect(find.text('5 de 5 estrelas'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$width px');
      }
    },
  );

  testWidgets(
    'detalhes com avaliação liberada cabem em 360 pixels com texto ampliado',
    (tester) async {
      await _sessao(
        'profissional',
        (_) async =>
            _json({'solicitacao': _pedido(status: 'conclusao_confirmada')}),
      );
      await _abrir(
        tester,
        AppRoutes.detalhesServico,
        arguments: 45,
        width: 360,
        scale: 1.6,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('avaliacao-enviar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('avaliacao-enviar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Avaliar cliente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profissional não recebe ações exclusivas do cliente no perfil público',
    (tester) async {
      await _sessao(
        'profissional',
        (_) async => _json({'resumo': {}, 'avaliacoes': []}),
      );
      await _abrir(
        tester,
        AppRoutes.perfilProfissional,
        arguments: profissionalFromApi(_perfil),
      );
      expect(
        find.byKey(const ValueKey('perfil-solicitar-servico')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('perfil-favorito-7')), findsNothing);
    },
  );

  testWidgets(
    'região usa o formulário validado e recarrega o perfil após salvar',
    (tester) async {
      var consultas = 0;
      Map<String, dynamic>? enviado;
      await _sessao('profissional', (request) async {
        if (request.url.path.endsWith('/profissionais/me')) {
          if (request.method == 'GET') consultas++;
          if (request.method == 'PUT') {
            enviado = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return _json({'profissional': _perfil});
        }
        return _json({'solicitacoes': []});
      });
      await _abrir(tester, AppRoutes.perfilProfissionalPrivado);
      await tester.ensureVisible(find.text('Região atendida'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Região atendida'));
      await tester.pumpAndSettle();
      expect(find.text('Editar perfil profissional'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'Bairro Novo');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profissional-continuar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Salvar alterações'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profissional-continuar')));
      await tester.pumpAndSettle();
      expect(enviado?['bairro'], 'Bairro Novo');
      expect(find.text('Meu perfil profissional'), findsOneWidget);
      expect(consultas, greaterThanOrEqualTo(4));
    },
  );
}
