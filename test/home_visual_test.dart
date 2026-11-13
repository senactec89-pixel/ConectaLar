import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/models/categoria.dart';
import 'package:conectarlar_app/models/home_content.dart';
import 'package:conectarlar_app/screens/home/home_mock_data.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppServices.instance = AppServices(modoDemo: true));

  testWidgets('categorias longas permanecem legíveis na Home', (tester) async {
    const nome = 'Instalação e manutenção de equipamentos residenciais';
    const dados = HomeContent(
      categories: [
        Categoria(id: 1, nome: nome),
        Categoria(id: 2, nome: 'Limpeza'),
      ],
    );
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
            home: HomePage(loadContent: () async => dados),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final titulo = find.text(nome);
        await tester.scrollUntilVisible(
          titulo,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(titulo).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });

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
            matching: find.text('Buscar'),
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
            'Busque, compare e solicite atendimento.',
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

        final favorito = find.byKey(
          ValueKey(
            'home-favorito-${HomeMockData.content.featuredProfessionals.first.id}',
          ),
        );
        await tester.scrollUntilVisible(
          favorito,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(favorito).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(favorito).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });

  testWidgets('saudação e busca não se sobrepõem com texto intermediário', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final largura in [320.0, 360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 1.1, 1.3, 1.4, 1.5, 2.0]) {
        tester.view.physicalSize = Size(largura, 844);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('hero-$largura-$escala'),
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

        final descricao = find.text('Busque, compare e solicite atendimento.');
        final busca = find.byKey(const ValueKey('home-search'));
        expect(
          tester.renderObject<RenderParagraph>(descricao).didExceedMaxLines,
          isFalse,
          reason: 'Descrição em $largura px, texto $escala×',
        );
        expect(
          tester.getTopLeft(busca).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(descricao).dy + 8),
          reason: 'Separação entre saudação e busca em $largura px, $escala×',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('busca da Home continua acessível em celular baixo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(loadContent: () async => HomeMockData.content),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final busca = find.byKey(const ValueKey('home-search'));
    await tester.ensureVisible(busca);
    await tester.pumpAndSettle();

    expect(busca.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marca e títulos da Home não são truncados em 320 px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(loadContent: () async => HomeMockData.content),
      ),
    );
    await tester.pumpAndSettle();

    for (final texto in [
      'Serviços para cuidar do seu lar',
      'Categorias',
      'de serviços',
      'Profissionais em destaque',
    ]) {
      final finder = find.text(texto, findRichText: true);
      expect(finder, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
        isFalse,
        reason: texto,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
