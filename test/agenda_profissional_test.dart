import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/screens/profissional/area_profissional_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

final _agora = DateTime.now();
final _mes = '${_agora.year}-${_agora.month.toString().padLeft(2, '0')}';
Finder _dia(int numero) => find.byKey(ValueKey('agenda-dia-$_mes-$numero'));

Map<String, dynamic> _pedido(
  int id,
  int dia,
  String hora, {
  String status = 'aceita_agendada',
}) => {
  'id': id,
  'nomeServico': 'Atendimento $id',
  'status': status,
  'dataServico': '$_mes-${dia.toString().padLeft(2, '0')}T00:00:00.000Z',
  'horarioServico': hora,
};

Map<String, dynamic> _dados() => {
  'atendimentos': [
    _pedido(2, 8, '14:00:00'),
    _pedido(1, 8, '09:00:00'),
    _pedido(3, 9, '10:00', status: 'aguardando_resposta'),
    _pedido(4, 9, '11:00', status: 'cancelada'),
    _pedido(5, 9, '12:00', status: 'recusada'),
    _pedido(6, 9, '13:00', status: 'conclusao_confirmada'),
  ],
  'disponibilidade': [
    {
      'diaSemana': DateTime(_agora.year, _agora.month, 8).weekday % 7,
      'horaInicio': '08:00:00',
      'horaFim': '18:00:00',
      'ativo': true,
    },
    {
      'diaSemana': DateTime(_agora.year, _agora.month, 9).weekday % 7,
      'horaInicio': '07:00',
      'horaFim': '19:00',
      'ativo': false,
    },
  ],
};

Future<void> _abrir(
  WidgetTester tester, {
  double width = 390,
  double escala = 1,
  Map<String, WidgetBuilder> overrides = const {},
}) => abrirFrontend(
  tester,
  AppRoutes.areaProfissional,
  width: width,
  textScale: escala,
  overrides: {
    AppRoutes.areaProfissional: (_) =>
        const AreaProfissionalPage(initialTab: 2),
    ...overrides,
  },
);

Future<void> _mostrar(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('agenda conta somente aceites e ordena os horários do dia', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async =>
          request.url.path.endsWith('/agenda') ? jsonResponse(_dados()) : null,
    );
    await _abrir(tester);
    expect(find.text('2 atendimentos em 1 dia'), findsOneWidget);
    expect(
      tester.widget<Semantics>(_dia(8)).properties.label,
      contains('2 atendimentos agendados'),
    );
    expect(
      tester.widget<Semantics>(_dia(9)).properties.label,
      contains('sem atendimentos agendados, sem horário semanal cadastrado'),
    );
    expect(
      tester.widget<Semantics>(_dia(15)).properties.label,
      contains('sem atendimentos agendados, com horário semanal cadastrado'),
    );
    await _mostrar(tester, find.text('08:00 às 18:00'));
    expect(find.text('08:00 às 18:00'), findsOneWidget);
    await _mostrar(tester, find.text('Atendimento 1'));
    final lista = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final primeiro =
        lista.position.pixels +
        tester.getTopLeft(find.text('Atendimento 1')).dy;
    await _mostrar(tester, find.text('Atendimento 2'));
    final segundo =
        lista.position.pixels +
        tester.getTopLeft(find.text('Atendimento 2')).dy;
    expect(primeiro, lessThan(segundo));
    expect(find.text('Atendimento 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dia sem horário ativo não é anunciado como livre', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async =>
          request.url.path.endsWith('/agenda') ? jsonResponse(_dados()) : null,
    );
    await _abrir(tester);
    await tester.tap(_dia(9));
    await tester.pumpAndSettle();
    await _mostrar(
      tester,
      find.text('Nenhum horário semanal cadastrado para este dia.'),
    );
    expect(find.text('07:00 às 19:00'), findsNothing);
    await _mostrar(tester, find.text('Nenhum atendimento neste dia'));
    expect(
      find.textContaining(
        'Solicitações aguardando resposta ainda não reservam horário.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'mudar mês consulta a agenda correta e limpa os indicadores anteriores',
    (tester) async {
      final consultas = <String?>[];
      await configurarFrontend(
        papel: 'profissional',
        responder: (request) async {
          if (!request.url.path.endsWith('/agenda')) return null;
          consultas.add(request.url.queryParameters['mes']);
          return jsonResponse(
            consultas.length == 1
                ? _dados()
                : {'atendimentos': [], 'disponibilidade': []},
          );
        },
      );
      await _abrir(tester);
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      final proximo = DateTime(_agora.year, _agora.month + 1);
      expect(consultas, [
        _mes,
        '${proximo.year}-${proximo.month.toString().padLeft(2, '0')}',
      ]);
      expect(
        find.text('Nenhum atendimento agendado neste mês'),
        findsOneWidget,
      );
      expect(find.text('2 atendimentos em 1 dia'), findsNothing);
    },
  );

  testWidgets(
    'retorno da edição recarrega os horários mantendo o dia selecionado',
    (tester) async {
      var consultas = 0;
      await configurarFrontend(
        papel: 'profissional',
        responder: (request) async {
          if (!request.url.path.endsWith('/agenda')) return null;
          consultas++;
          return jsonResponse({
            ..._dados(),
            if (consultas > 1) 'disponibilidade': [],
          });
        },
      );
      await _abrir(
        tester,
        overrides: {
          AppRoutes.disponibilidadeProfissional: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar à agenda'),
            ),
          ),
        },
      );
      await tester.tap(_dia(15));
      await tester.pumpAndSettle();
      await _mostrar(tester, find.text('Editar disponibilidade semanal'));
      await tester.tap(find.text('Editar disponibilidade semanal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar à agenda'));
      await tester.pumpAndSettle();
      expect(consultas, 2);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(_dia(15)).properties.selected, isTrue);
      await _mostrar(
        tester,
        find.text('Nenhum horário semanal cadastrado para este dia.'),
      );
    },
  );

  testWidgets('falha na agenda oferece nova tentativa sem anunciar dia vazio', (
    tester,
  ) async {
    var falhar = true;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async => request.url.path.endsWith('/agenda')
          ? falhar
                ? jsonResponse({'message': 'Indisponível'}, 503)
                : jsonResponse(_dados())
          : null,
    );
    await _abrir(tester);
    expect(find.text('Nenhum atendimento agendado neste mês'), findsNothing);
    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('2 atendimentos em 1 dia'), findsOneWidget);
  });

  testWidgets(
    'agenda e atendimentos cabem nas três larguras com texto ampliado',
    (tester) async {
      await configurarFrontend(
        papel: 'profissional',
        responder: (request) async => request.url.path.endsWith('/agenda')
            ? jsonResponse(_dados())
            : null,
      );
      for (final width in [360.0, 390.0, 412.0]) {
        for (final escala in [1.0, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await _abrir(tester, width: width, escala: escala);
          await _mostrar(tester, find.text('Atendimento 2'));
          await _mostrar(
            tester,
            find.textContaining('Antes de aceitar outro pedido'),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$width px, texto $escala',
          );
        }
      }
    },
  );
}
