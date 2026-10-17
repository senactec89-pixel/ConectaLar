import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/models/profissional.dart';
import 'package:conectarlar_app/screens/profissional/comparar_profissionais_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  Future<void> tornarAcionavel(WidgetTester tester, Finder alvo) async {
    await tester.scrollUntilVisible(
      alvo,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
    expect(alvo.hitTestable(), findsOneWidget);
  }

  testWidgets('cliente seleciona dois profissionais e abre comparação', (
    tester,
  ) async {
    await configurarFrontend();
    await abrirFrontend(tester, AppRoutes.busca, width: 390);

    final primeiro = find.byKey(const ValueKey('busca-comparar-1'));
    await tornarAcionavel(tester, primeiro);
    await tester.tap(primeiro);
    await tester.pumpAndSettle();
    expect(find.text('1 de 2 selecionados'), findsOneWidget);

    final segundo = find.byKey(const ValueKey('busca-comparar-2'));
    await tester.scrollUntilVisible(
      segundo,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(segundo);
    await tester.pumpAndSettle();
    expect(segundo.hitTestable(), findsOneWidget);
    await tester.tap(segundo);
    await tester.pumpAndSettle();

    expect(find.text('2 de 2 selecionados'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('busca-comparacao-abrir')));
    await tester.pumpAndSettle();
    expect(
      find.text('Compare informações públicas dos perfis.'),
      findsOneWidget,
    );
    expect(find.text('Carlos Silva'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Avaliações'), findsOneWidget);
    expect(find.text('Localização'), findsOneWidget);
    expect(find.text('Serviços oferecidos'), findsOneWidget);
    expect(find.text('Preço inicial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparação é oferecida somente para a conta cliente', (
    tester,
  ) async {
    for (final papel in ['profissional', 'empresa', 'administrador']) {
      await configurarFrontend(papel: papel);
      await abrirFrontend(tester, AppRoutes.busca);
      expect(
        find.byKey(const ValueKey('busca-comparar-1')),
        findsNothing,
        reason: papel,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('tela de comparação se adapta a larguras e texto ampliado', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final width in [360.0, 390.0, 412.0]) {
      for (final textScale in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: CompararProfissionaisPage(
              profissionais: _profissionaisExemplo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Comparar profissionais'), findsOneWidget);
        for (final titulo in [
          'Avaliações',
          'Localização',
          'Serviços oferecidos',
          'Preço inicial',
        ]) {
          final campo = find.text(titulo);
          await tester.scrollUntilVisible(
            campo,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          expect(campo, findsOneWidget);
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '$width px / escala $textScale',
        );
      }
    }
  });
}

const _profissionaisExemplo = [
  Profissional(
    id: 1,
    usuarioId: 101,
    nome: 'Carlos Silva',
    descricao: 'Eletricista residencial',
    bairro: 'Centro',
    cidade: 'Belo Horizonte',
    uf: 'MG',
    precoInicial: 80,
    verificado: true,
    notaMedia: 4.8,
    quantidadeAvaliacoes: 120,
    servicos: ['Elétrica', 'Manutenção'],
  ),
  Profissional(
    id: 2,
    usuarioId: 102,
    nome: 'Ana Souza',
    descricao: 'Limpeza residencial',
    bairro: 'Vila Nova',
    cidade: 'Belo Horizonte',
    uf: 'MG',
    precoInicial: 70,
    notaMedia: 4.9,
    quantidadeAvaliacoes: 98,
    servicos: ['Limpeza'],
  ),
];
