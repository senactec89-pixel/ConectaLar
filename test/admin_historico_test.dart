import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/models/solicitacao.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

const _registro = {
  'id': 45,
  'status': 'conclusao_confirmada',
  'cliente': {'nome': 'Cliente do atendimento'},
  'profissional': {'nome': 'Profissional do atendimento'},
  'categoria': {'nome': 'Elétrica'},
  'bairroAtendimento': 'Centro',
  'descricao': 'Instalação elétrica residencial.',
  'dataServico': '2026-10-11',
  'horarioServico': '10:00',
  'precoInicial': 100,
  'criadoEm': '2026-10-10T12:00:00Z',
  'atualizadoEm': '2026-10-11T12:00:00Z',
  'enderecoAtendimento': {'logradouro': 'Endereço privado não exibível'},
};

Future<void> _verResultados(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('prévia administrativa mostra histórico fictício sem endereço', (
    tester,
  ) async {
    await configurarFrontend(papel: 'administrador');
    await abrirFrontend(tester, AppRoutes.adminHistorico);
    await _verResultados(tester, find.text('Atendimento #1001'));
    expect(find.text('Atendimento #1001'), findsOneWidget);
    expect(find.textContaining('Rua de exemplo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('histórico consulta endpoint admin, aplica filtros e limpa', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/admin/historico/atendimentos') return null;
        queries.add(request.url.queryParameters);
        return jsonResponse({
          'atendimentos': [_registro],
        });
      },
    );
    await abrirFrontend(tester, AppRoutes.adminHistorico);
    expect(queries.single, isEmpty);
    await tester.tap(find.byType(DropdownButtonFormField<StatusSolicitacao?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelada').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('historico-usuario')),
      '42',
    );
    await _verResultados(tester, find.text('Somente finalizados'));
    await tester.tap(find.text('Somente finalizados'));
    await _verResultados(tester, find.text('Aplicar filtros'));
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(queries.last, {
      'status': 'cancelada',
      'usuarioId': '42',
      'finalizados': 'true',
    });
    await _verResultados(tester, find.text('Limpar filtros'));
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(queries.last, isEmpty);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('historico-usuario')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro e resposta inválida permitem retry antes do vazio real', (
    tester,
  ) async {
    var chamadas = 0;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/admin/historico/atendimentos') return null;
        chamadas++;
        return switch (chamadas) {
          1 => jsonResponse({'message': 'Falha'}, 503),
          2 => jsonResponse({}),
          _ => jsonResponse({'atendimentos': []}),
        };
      },
    );
    await abrirFrontend(tester, AppRoutes.adminHistorico);
    await _verResultados(tester, find.text('Tentar novamente'));
    expect(find.text('Nenhum atendimento neste filtro'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await _verResultados(tester, find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum atendimento neste filtro'), findsOneWidget);
    expect(chamadas, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conta não administrativa não consulta histórico', (
    tester,
  ) async {
    var chamadas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/admin/historico/atendimentos') chamadas++;
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.adminHistorico);
    expect(find.text('Área indisponível para esta conta'), findsOneWidget);
    expect(chamadas, 0);
  });

  testWidgets('histórico é somente leitura em 360, 390 e 412 com texto 200%', (
    tester,
  ) async {
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (request.url.path != '/admin/historico/atendimentos') return null;
        return jsonResponse({
          'atendimentos': [_registro],
        });
      },
    );
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.adminHistorico,
        width: width,
        textScale: 1,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('historico-usuario')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Rolagem em $width');
      await tester.showKeyboard(
        find.byKey(const ValueKey('historico-usuario')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Foco em $width');
      // O binding agenda um frame extra ao focar este campo já em 200%.
      // Amplie depois do foco para verificar o layout com teclado e fonte 200%.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Fonte em $width');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Teclado em $width');
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await _verResultados(tester, find.text('Atendimento #45'));
      expect(find.text('Atendimento #45'), findsOneWidget);
      expect(find.textContaining('Endereço privado'), findsNothing);
      expect(find.text('Aceitar solicitação'), findsNothing);
      expect(find.text('Confirmar conclusão'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
