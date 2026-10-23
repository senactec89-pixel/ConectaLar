import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/models/profissional.dart';
import 'package:conectarlar_app/widgets/profissional_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profissional = Profissional(
  id: 33,
  usuarioId: 133,
  nome: 'João Henrique de Almeida e Souza',
  descricao: 'Instalação e manutenção de equipamentos residenciais',
  bairro: 'Jardim das Flores e região de atendimento residencial',
  precoInicial: 9999999.99,
  verificado: true,
  fotoAsset: 'assets/images/home/professional_carlos.png',
  notaMedia: 4.9,
  quantidadeAvaliacoes: 12345678,
  servicos: [
    'Instalação de equipamentos de ar-condicionado',
    'Manutenção elétrica residencial',
    'Reparos e assistência técnica',
    'Quarto serviço',
  ],
);

void main() {
  testWidgets(
    'card preserva leitura e callbacks com dados longos e texto 200%',
    (tester) async {
      var perfis = 0;
      var favoritos = 0;
      for (final width in [360.0, 390.0, 412.0]) {
        for (final scale in [1.0, 1.4, 2.0]) {
          await _abrirCard(
            tester,
            width: width,
            scale: scale,
            card: ProfissionalCard(
              profissional: _profissional,
              onTap: () => perfis++,
              trailingAction: IconButton(
                key: const ValueKey('card-favorito'),
                tooltip: 'Remover favorito',
                onPressed: () => favoritos++,
                icon: const Icon(Icons.favorite),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$width px, $scale');
          final foto = tester.widget<Image>(find.byType(Image));
          expect(foto.fit, BoxFit.cover);
          expect(foto.alignment, Alignment.topCenter);
          expect(tester.getSize(find.byType(Image)), const Size(76, 94));
          expect(find.text('Quarto serviço'), findsNothing);
          expect(find.text('4,9 · 12345678 avaliações'), findsOneWidget);
          expect(find.byTooltip('Documentos verificados'), findsOneWidget);
          if (scale == 2) {
            for (final texto in [
              _profissional.nome,
              _profissional.descricao,
              _profissional.bairro,
              _profissional.servicos.first,
              '4,9 · 12345678 avaliações',
            ]) {
              expect(tester.widget<Text>(find.text(texto)).maxLines, isNull);
            }
          }
          final preco = find.text('A partir de R\$ 9999999,99');
          await tester.ensureVisible(preco);
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(preco).maxLines, isNull);
          expect(tester.getRect(preco).right, lessThanOrEqualTo(width - 20));
          final remover = find.byKey(const ValueKey('card-favorito'));
          await tester.ensureVisible(remover);
          await tester.pumpAndSettle();
          final favoritosAntes = favoritos;
          final perfisAntes = perfis;
          expect(remover.hitTestable(), findsOneWidget);
          await tester.tap(remover);
          await tester.pumpAndSettle();
          expect(favoritos, favoritosAntes + 1);
          expect(perfis, perfisAntes);
          final perfil = find.ancestor(
            of: find.text('Ver perfil'),
            matching: find.bySubtype<TextButton>(),
          );
          await tester.ensureVisible(perfil);
          await tester.pumpAndSettle();
          expect(tester.getSize(perfil).height, greaterThanOrEqualTo(48));
          expect(perfil.hitTestable(), findsOneWidget);
          await tester.tap(perfil);
          await tester.pumpAndSettle();
          expect(perfis, perfisAntes + 1);
          expect(favoritos, favoritosAntes + 1);
          await tester.ensureVisible(find.text(_profissional.nome));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_profissional.nome));
          await tester.pumpAndSettle();
          expect(perfis, perfisAntes + 2);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('card mostra singular e adapta preço e ação à largura', (
    tester,
  ) async {
    const profissional = Profissional(
      id: 35,
      usuarioId: 135,
      nome: 'Ana Silva',
      descricao: 'Manutenção residencial',
      bairro: 'Centro',
      precoInicial: 120,
      notaMedia: 5,
      quantidadeAvaliacoes: 1,
    );
    for (final width in [360.0, 390.0, 412.0, 600.0]) {
      await _abrirCard(
        tester,
        width: width,
        scale: 1,
        card: ProfissionalCard(
          profissional: profissional,
          onTap: () {},
          trailingAction: IconButton(
            tooltip: 'Comparar profissional',
            onPressed: () {},
            icon: const Icon(Icons.compare_arrows),
          ),
        ),
      );
      expect(find.text('5,0 · 1 avaliação'), findsOneWidget);
      final preco = tester.getRect(find.text(r'A partir de R$ 120,00'));
      final acao = tester.getRect(find.text('Ver perfil'));
      // A fonte de teste é mais larga que a usada no app. Também exercita
      // o empilhamento quando manter o valor inteiro exige mais espaço.
      if (width == 600 || preco.right < acao.left) {
        expect(preco.center.dy, closeTo(acao.center.dy, 2));
        expect(preco.right, lessThan(acao.left));
      } else {
        expect(preco.bottom, lessThan(acao.top));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'card sem foto, nota ou preço mantém estados e botão desativado',
    (tester) async {
      const profissional = Profissional(
        id: 34,
        usuarioId: 134,
        nome: 'Novo profissional',
        descricao: '',
        bairro: 'Vila Nova',
      );
      for (final width in [360.0, 390.0, 412.0]) {
        await _abrirCard(
          tester,
          width: width,
          scale: 2,
          card: const ProfissionalCard(profissional: profissional),
        );
        expect(find.text('Preço sob consulta'), findsOneWidget);
        expect(find.text('Novo profissional'), findsNWidgets(2));
        expect(find.text('Verificado'), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(find.text('N'), findsOneWidget);
        final perfil = find.ancestor(
          of: find.text('Ver perfil'),
          matching: find.bySubtype<TextButton>(),
        );
        await tester.ensureVisible(perfil);
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(perfil).onPressed, isNull);
        expect(tester.getSize(perfil).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _abrirCard(
  WidgetTester tester, {
  required double width,
  required double scale,
  required ProfissionalCard card,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(20), children: [card]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
