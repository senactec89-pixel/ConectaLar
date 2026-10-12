import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/widgets/async_state_view.dart';
import 'package:conectarlar_app/widgets/session_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('carregamento tem texto visível e anúncio acessível único', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final width in [360.0, 390.0, 412.0]) {
        await _abrir(
          tester,
          const AsyncLoadingView(label: 'Carregando seus dados.'),
          width: width,
        );
        expect(find.text('Carregando seus dados.'), findsOneWidget);
        final anuncio = find.bySemanticsLabel('Carregando seus dados.');
        expect(anuncio, findsOneWidget);
        expect(
          tester
              .getSemantics(anuncio)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('erro mantém nova tentativa acessível por toque e teclado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var tentativas = 0;
      for (final width in [360.0, 390.0, 412.0]) {
        await _abrir(
          tester,
          AsyncErrorView(
            message: 'Não foi possível carregar seus dados. Tente novamente.',
            onRetry: () => tentativas++,
          ),
          width: width,
        );
        final retry = find.widgetWithText(OutlinedButton, 'Tentar novamente');
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        expect(tester, meetsGuideline(androidTapTargetGuideline));
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        final antes = tentativas;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tentativas, antes + 1);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(tentativas, antes + 2);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('estado vazio conserva ação e texto em altura reduzida', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var buscas = 0;
      await _abrir(
        tester,
        EmptyStateView(
          title: 'Nenhum profissional encontrado',
          message: 'Ajuste os filtros para consultar outros profissionais.',
          action: TextButton(
            onPressed: () => buscas++,
            child: const Text('Buscar profissionais'),
          ),
        ),
      );
      final acao = find.widgetWithText(TextButton, 'Buscar profissionais');
      await tester.ensureVisible(acao);
      await tester.pumpAndSettle();
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(buscas, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('estado de acesso exige login e conserva a rota existente', (
    tester,
  ) async {
    AppServices.instance = AppServices();
    var privado = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Tela de login')),
        },
        home: SessionGate(
          builder: (_) {
            privado = true;
            return const Text('Conteúdo privado');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(privado, isFalse);
    expect(find.text('Conteúdo privado'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Tela de login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acesso restrito não constrói conteúdo de outro papel', (
    tester,
  ) async {
    await configurarFrontend();
    var privado = false;
    await _abrir(
      tester,
      SessionGate(
        papeis: const {'administrador'},
        builder: (_) {
          privado = true;
          return const Text('Conteúdo administrativo privado');
        },
      ),
    );
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(
      find.text('Esta área não está disponível para o seu tipo de conta.'),
      findsOneWidget,
    );
    expect(privado, isFalse);
    expect(find.text('Conteúdo administrativo privado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botões conservam área mínima em celular e desktop', (
    tester,
  ) async {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(
            platform: platform,
            visualDensity: platform == TargetPlatform.android
                ? VisualDensity.standard
                : VisualDensity.compact,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(onPressed: () {}, child: const Text('Salvar')),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Tentar novamente'),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Cancelar')),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {},
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(52),
        reason: '$platform',
      );
      for (final type in [OutlinedButton, TextButton, IconButton]) {
        final size = tester.getSize(find.byType(type));
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason: '$type em $platform',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(48),
          reason: '$type em $platform',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  test('cores originais mantêm contraste nos pares principais de leitura', () {
    for (final par in [
      (AppColors.branco, AppColors.verde),
      (AppColors.texto, AppColors.branco),
      (AppColors.textoSuave, AppColors.branco),
      (AppColors.textoSuave, AppColors.fundo),
      (AppColors.verdeEscuro, AppColors.verdeClaro),
      (AppColors.erro, AppColors.branco),
    ]) {
      final valores = [par.$1.computeLuminance(), par.$2.computeLuminance()]
        ..sort();
      expect(
        (valores.last + 0.05) / (valores.first + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

Future<void> _abrir(
  WidgetTester tester,
  Widget child, {
  double width = 360,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 220);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}
