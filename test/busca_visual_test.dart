import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/models/categoria.dart';
import 'package:conectarlar_app/screens/home/home_mock_data.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/widgets/profissional_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('busca reserva mais espaço para resultados sem filtros ativos', (
    tester,
  ) async {
    await configurarFrontend();
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(tester, AppRoutes.busca, width: width);
      expect(find.text('Buscar profissionais'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsNothing);
      expect(find.text('2 profissionais encontrados'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ProfissionalCard).first).dy,
        lessThan(tester.view.physicalSize.height * 2 / 3),
        reason: 'Primeiro resultado visível mais cedo em $width px',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('localização recolhida mostra os filtros ativos', (tester) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.busca);
    await tester.tap(find.byKey(const ValueKey('busca-localizacao-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('busca-bairro')),
      'Vila Nova',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('busca-localizacao-toggle')));
    await tester.pumpAndSettle();
    final filtros = find.ancestor(
      of: find.byKey(const ValueKey('busca-localizacao-toggle')),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: filtros, matching: find.text('Vila Nova')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('busca-bairro')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('busca-localizacao-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('busca-bairro')))
          .controller!
          .text,
      'Vila Nova',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'busca organiza categoria e limpeza sem reduzir a área de toque',
    (tester) async {
      await configurarFrontend();
      final categoria = HomeMockData.content.categories.first;
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.busca,
          arguments: categoria,
          width: width,
        );
        final selecionada = find.text('Categoria: ${categoria.nome}');
        final limpar = find.ancestor(
          of: find.text('Limpar filtros'),
          matching: find.bySubtype<TextButton>(),
        );
        await tester.tap(
          find.byKey(const ValueKey('busca-localizacao-toggle')),
        );
        await tester.pumpAndSettle();
        final campo = tester.getRect(find.byKey(const ValueKey('busca-termo')));
        expect(tester.getRect(selecionada).left, closeTo(campo.left, 1));
        expect(tester.getRect(limpar).right, lessThanOrEqualTo(campo.right));
        expect(tester.getSize(limpar).height, greaterThanOrEqualTo(48));
        expect(limpar.hitTestable(), findsOneWidget);
        await tester.tap(limpar);
        await tester.pumpAndSettle();
        expect(selecionada, findsNothing);
        expect(limpar, findsNothing);
        expect(find.text('2 profissionais encontrados'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('resumo de categoria longa cabe com texto 200% e teclado', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/profissionais'
          ? jsonResponse({'profissionais': []})
          : null,
    );
    const categoria = Categoria(
      id: 8,
      nome: 'Manutenção e instalação de ar-condicionado residencial',
    );
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.busca,
        arguments: categoria,
        width: width,
        textScale: 2,
      );
      final selecionada = find.text('Categoria: ${categoria.nome}');
      await tester.scrollUntilVisible(
        selecionada,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(selecionada).maxLines, isNull);
      expect(tester.getRect(selecionada).right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final limpar = find.ancestor(
        of: find.text('Limpar filtros'),
        matching: find.bySubtype<TextButton>(),
      );
      await tester.ensureVisible(limpar);
      await tester.pumpAndSettle();
      expect(limpar.hitTestable(), findsOneWidget);
      expect(tester.getSize(limpar).height, greaterThanOrEqualTo(48));
      await tester.tap(limpar);
      await tester.pumpAndSettle();
      expect(limpar, findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }
  });

  testWidgets('busca mantém resultados e filtros acessíveis com texto 200%', (
    tester,
  ) async {
    await configurarFrontend();
    addTearDown(tester.view.resetViewInsets);
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      AppServices.instance.buscaEstado.limpar();
      await abrirFrontend(tester, AppRoutes.busca, width: width, textScale: 2);
      await tester.scrollUntilVisible(
        find.text('2 profissionais encontrados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull, reason: 'Resultados em $width');
      await tester.tap(find.byKey(const ValueKey('busca-localizacao-toggle')));
      await tester.pumpAndSettle();
      final bairro = find.byKey(const ValueKey('busca-bairro'));
      await tester.ensureVisible(bairro);
      await tester.enterText(bairro, 'Vila Nova');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Teclado em $width');
      await tester.scrollUntilVisible(
        find.text('1 profissional encontrado'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      final limpar = find.ancestor(
        of: find.text('Limpar filtros'),
        matching: find.bySubtype<TextButton>(),
      );
      await tester.ensureVisible(limpar);
      await tester.pumpAndSettle();
      await tester.tap(limpar);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Categorias'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      final outrasCategorias = find.widgetWithText(FilterChip, 'Outros');
      await tester.ensureVisible(outrasCategorias);
      await tester.pumpAndSettle();
      expect(outrasCategorias.hitTestable(), findsOneWidget);
      await tester.tap(outrasCategorias);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(outrasCategorias).selected, isTrue);
      await tester.scrollUntilVisible(
        find.text('Nenhum profissional corresponde a esta busca.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('busca identifica categoria recebida da Home com texto 200%', (
    tester,
  ) async {
    await configurarFrontend();
    final categoria = HomeMockData.content.categories.last;
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.busca,
        arguments: categoria,
        width: width,
        textScale: 2,
      );
      final selecionada = find.text('Categoria: ${categoria.nome}');
      expect(selecionada, findsOneWidget);
      await tester.ensureVisible(selecionada);
      await tester.pumpAndSettle();
      expect(tester.getRect(selecionada).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(selecionada).right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('filtros e cabeçalho de busca vazia cabem com texto 200%', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/profissionais'
          ? jsonResponse({'profissionais': []})
          : null,
    );
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(tester, AppRoutes.busca, width: width, textScale: 2);
      await tester.scrollUntilVisible(
        find.text('0 profissionais encontrados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('0 profissionais encontrados')).width,
        lessThanOrEqualTo(width - 40),
      );
      await tester.scrollUntilVisible(
        find.text('Nenhum profissional corresponde a esta busca.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
