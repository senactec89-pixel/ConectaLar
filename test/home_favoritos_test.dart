import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/screens/home/home_mock_data.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  final home = <String, WidgetBuilder>{
    AppRoutes.home: (_) =>
        HomePage(loadContent: () async => HomeMockData.content),
  };
  final favorito = find.byKey(const ValueKey('home-favorito-1'));

  Future<void> mostrarFavorito(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      favorito,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home salva e restaura favoritos, sem mudar o ícone em falha', (
    tester,
  ) async {
    var salvo = false;
    var falhar = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.startsWith('/clientes/me/favoritos/')) {
          if (request.method == 'GET') return jsonResponse({'favorito': salvo});
          if (falhar) return jsonResponse({'message': 'Erro'}, 503);
          salvo = request.method == 'POST';
          return jsonResponse({});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.home, overrides: home);
    await mostrarFavorito(tester);
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Adicionar aos favoritos',
    );

    await tester.tap(favorito);
    await tester.pumpAndSettle();
    expect(salvo, isTrue);
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Remover dos favoritos',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await abrirFrontend(tester, AppRoutes.home, overrides: home);
    await mostrarFavorito(tester);
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Remover dos favoritos',
    );

    falhar = true;
    await tester.tap(favorito);
    await tester.pumpAndSettle();
    expect(salvo, isTrue);
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Remover dos favoritos',
    );
    expect(
      find.text('Não foi possível remover este favorito.'),
      findsOneWidget,
    );
    falhar = false;
    await tester.tap(favorito);
    await tester.pumpAndSettle();
    expect(salvo, isFalse);
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Adicionar aos favoritos',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao consultar favorito permite nova tentativa', (
    tester,
  ) async {
    var falhar = true;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.startsWith('/clientes/me/favoritos/')) {
          return falhar
              ? jsonResponse({'message': 'Erro'}, 503)
              : jsonResponse({'favorito': true});
        }
        return null;
      },
    );
    await abrirFrontend(tester, AppRoutes.home, overrides: home);
    await mostrarFavorito(tester);
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Não foi possível carregar favorito. Tentar novamente',
    );
    falhar = false;
    await tester.tap(favorito);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Remover dos favoritos',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('conta profissional não oferece ação de favorito', (
    tester,
  ) async {
    await configurarFrontend(papel: 'profissional');
    await abrirFrontend(tester, AppRoutes.home, overrides: home);
    await tester.scrollUntilVisible(
      find.text('Profissionais em destaque', findRichText: true),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(favorito, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home atualiza favorito ao voltar do perfil', (tester) async {
    var salvo = false;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.startsWith('/clientes/me/favoritos/')) {
          return jsonResponse({'favorito': salvo});
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.home,
      overrides: {
        ...home,
        AppRoutes.perfilProfissional: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              salvo = true;
              Navigator.pop(context);
            },
            child: const Text('Voltar do perfil'),
          ),
        ),
      },
    );
    await mostrarFavorito(tester);
    await tester.tap(find.text('Carlos Silva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar do perfil'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(favorito).tooltip,
      'Remover dos favoritos',
    );
    expect(tester.takeException(), isNull);
  });
}
