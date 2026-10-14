import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/home/home_mock_data.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppServices.instance = AppServices(modoDemo: true));

  testWidgets('Home mantém categorias e ações legíveis em larguras mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 2.0]) {
        tester.view.physicalSize = Size(largura, 844);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$largura-$escala'),
            theme: AppTheme.light,
            home: HomePage(loadContent: () async => HomeMockData.content),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');

        if (escala == 2) {
          final buscaCompacta = find.descendant(
            of: find.byKey(const ValueKey('home-search')),
            matching: find.text('Busca'),
          );
          expect(buscaCompacta, findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(buscaCompacta)
                .didExceedMaxLines,
            isFalse,
            reason: '${tester.getSize(buscaCompacta)} em $largura',
          );
          final descricao = find.text(
            'Encontre profissionais para cuidar do seu lar',
          );
          expect(
            tester.renderObject<RenderParagraph>(descricao).didExceedMaxLines,
            isFalse,
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('home-search'))).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(descricao).dy),
          );
        }

        final categoria = find.text('Ar-\ncondicionado');
        await tester.scrollUntilVisible(
          categoria,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Perto de você'), findsOneWidget);
        expect(find.text('Ver profissionais da região'), findsOneWidget);
        if (escala == 2) {
          final tituloCategorias = find.text(
            'Categorias de serviços',
            findRichText: true,
          );
          expect(tituloCategorias, findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(tituloCategorias)
                .didExceedMaxLines,
            isFalse,
          );
        }
        final texto = tester.renderObject<RenderParagraph>(categoria);
        expect(
          texto.didExceedMaxLines,
          isFalse,
          reason: 'Categoria em $largura px, $escala×',
        );
        final verTodas = find.ancestor(
          of: find.text('Ver todas'),
          matching: find.bySubtype<TextButton>(),
        );
        expect(tester.getSize(verTodas).height, greaterThanOrEqualTo(48));

        await tester.scrollUntilVisible(
          find.byTooltip('Adicionar aos favoritos').first,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final favorito = find.byTooltip('Adicionar aos favoritos').first;
        expect(tester.getSize(favorito).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(favorito).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });
}
