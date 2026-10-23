import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/perfil/editar_dados_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('Meus dados mostra a ajuda inteira com texto 200% e teclado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    AppServices.instance = AppServices(modoDemo: true);

    for (final largura in [360.0, 390.0, 412.0]) {
      tester.view.physicalSize = Size(largura, 844);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(largura),
          theme: AppTheme.light,
          home: const EditarDadosPage(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$largura px');

      final ajuda = find.text(
        'E-mail vinculado à conta. Você pode consultá-lo aqui.',
      );
      await tester.scrollUntilVisible(
        ajuda,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.renderObject<RenderParagraph>(ajuda).didExceedMaxLines,
        isFalse,
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('perfil-salvar')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$largura px com teclado');
      tester.view.resetViewInsets();
    }
  });

  testWidgets('erro de Meus dados mantém nova tentativa em altura reduzida', (
    tester,
  ) async {
    AppServices.instance = AppServices(modoDemo: false);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 220);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const EditarDadosPage(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithText(OutlinedButton, 'Tentar novamente'))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
