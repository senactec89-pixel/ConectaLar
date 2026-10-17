import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'favoritos mostra quantidade e remoção tem alvo de toque de 48 px',
    (tester) async {
      await configurarFrontend();
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(tester, AppRoutes.favoritos, width: width);
        expect(find.text('2 salvos'), findsOneWidget);
        final remover = find.byKey(const ValueKey('favorito-remover-1'));
        await tester.ensureVisible(remover);
        await tester.pumpAndSettle();
        expect(tester.getSize(remover).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(remover).height, greaterThanOrEqualTo(48));
        expect(remover.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(remover);
        await tester.pumpAndSettle();
        expect(
          find.text('Não foi possível remover o favorito.'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('favoritos atualiza ao puxar a lista', (tester) async {
    var consultas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/clientes/me/favoritos') {
          consultas++;
          return jsonResponse({'favoritos': []});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.favoritos);
    expect(consultas, 1);

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(consultas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favoritos preenchido mantém botão acessível com texto 200%', (
    tester,
  ) async {
    await configurarFrontend();
    for (final width in [360.0, 390.0, 412.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.favoritos,
        width: width,
        textScale: 2,
      );
      final remover = find.byKey(const ValueKey('favorito-remover-1'));
      await tester.ensureVisible(remover);
      await tester.pumpAndSettle();
      expect(remover.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'favoritos vazio apresenta quantidade e orientação com texto 200%',
    (tester) async {
      await configurarFrontend(
        responder: (request) async =>
            request.url.path == '/clientes/me/favoritos'
            ? jsonResponse({'favoritos': []})
            : null,
      );
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await abrirFrontend(
          tester,
          AppRoutes.favoritos,
          width: width,
          textScale: 2,
        );
        expect(find.text('0 salvos'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Sua lista está vazia'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final buscar = find.text('Buscar profissionais');
        await tester.scrollUntilVisible(
          buscar,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(buscar.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('vazio em favoritos oferece caminho para a Busca', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/clientes/me/favoritos'
          ? jsonResponse({'favoritos': []})
          : null,
    );
    await abrirFrontend(
      tester,
      AppRoutes.favoritos,
      overrides: {
        AppRoutes.busca: (_) => const Scaffold(body: Text('Busca aberta')),
      },
    );

    await tester.tap(find.text('Buscar profissionais'));
    await tester.pumpAndSettle();

    expect(find.text('Busca aberta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
