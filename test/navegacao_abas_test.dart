import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  Future<void> selecionarAba(WidgetTester tester, String titulo) async {
    final destino = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(titulo),
    );
    await tester.tap(destino);
    await tester.pumpAndSettle();
  }

  String rotaAtual(WidgetTester tester) => ModalRoute.of(
    tester.element(find.byType(BottomNavigationCustom)),
  )!.settings.name!;

  testWidgets('voltar após trocar abas retorna diretamente ao Início', (
    tester,
  ) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.home);

    for (final aba in [
      ('Buscar', AppRoutes.busca),
      ('Favoritos', AppRoutes.favoritos),
      ('Pedidos', AppRoutes.meusServicos),
      ('Perfil', AppRoutes.perfil),
    ]) {
      await selecionarAba(tester, aba.$1);
      expect(rotaAtual(tester), aba.$2);
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(rotaAtual(tester), AppRoutes.home);
    expect(
      Navigator.of(
        tester.element(find.byType(BottomNavigationCustom)),
      ).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('aba aberta diretamente substitui a anterior', (tester) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.busca);
    await selecionarAba(tester, 'Favoritos');

    expect(rotaAtual(tester), AppRoutes.favoritos);
    expect(
      Navigator.of(
        tester.element(find.byType(BottomNavigationCustom)),
      ).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Busca preserva filtros e rolagem ao trocar de aba', (
    tester,
  ) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.home);
    await selecionarAba(tester, 'Buscar');
    await tester.enterText(find.byKey(const ValueKey('busca-termo')), 'Carlos');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    final lista = tester.widget<ListView>(find.byType(ListView).first);
    lista.controller!.jumpTo(150);
    await tester.pumpAndSettle();
    await selecionarAba(tester, 'Favoritos');
    await selecionarAba(tester, 'Buscar');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('busca-termo')))
          .controller!
          .text,
      'Carlos',
    );
    expect(
      tester.widget<ListView>(find.byType(ListView).first).controller!.offset,
      150,
    );
    expect(tester.takeException(), isNull);
    await AppServices.instance.auth.logout();
    expect(AppServices.instance.buscaEstado.termo, isEmpty);
    expect(AppServices.instance.buscaEstado.rolagem, 0);
  });
}
