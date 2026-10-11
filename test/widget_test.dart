import 'package:conectarlar_app/app/app.dart';
import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/models/home_content.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a Home exibe categorias e profissionais mockados', (
    tester,
  ) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Encontre profissionais para cuidar do seu lar'),
      findsOneWidget,
    );
    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Limpeza'), findsOneWidget);
    expect(find.text('Profissionais em destaque'), findsOneWidget);
    expect(find.text('Carlos Silva'), findsOneWidget);
  });

  testWidgets('a busca da Home abre a rota Buscar', (tester) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();

    expect(find.text('Buscar profissionais'), findsOneWidget);
  });

  testWidgets('a categoria da Home abre a busca filtrada', (tester) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpeza'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar profissionais'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ana Souza'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Carlos Silva'), findsNothing);
  });

  testWidgets('a busca filtra profissionais por termo e bairro', (
    tester,
  ) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('busca-termo')),
      'limpeza',
    );
    await tester.enterText(find.byKey(const ValueKey('busca-bairro')), 'vila');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ana Souza'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Carlos Silva'), findsNothing);
  });

  testWidgets('o perfil profissional mostra detalhes e abre solicitação', (
    tester,
  ) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Carlos Silva'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Silva'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil profissional'), findsOneWidget);
    expect(find.text('Eletricista residencial'), findsOneWidget);
    expect(find.text('Serviços oferecidos'), findsOneWidget);
    expect(find.text('Antes de solicitar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('perfil-solicitar-servico')));
    await tester.pumpAndSettle();

    expect(find.text('Solicitar serviço'), findsOneWidget);
    expect(find.text('Dados da solicitação'), findsOneWidget);
    expect(find.textContaining('O envio não confirma'), findsOneWidget);
  });

  testWidgets('a solicitação enviada inicia aguardando resposta', (
    tester,
  ) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Carlos Silva'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Silva'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('perfil-solicitar-servico')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('solicitar-bairro')),
      'Jardim das Flores',
    );
    await tester.enterText(
      find.byKey(const ValueKey('solicitar-data')),
      '15/10/2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('solicitar-horario')),
      '14:00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('solicitar-descricao')),
      'Instalar chuveiro no banheiro social.',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('solicitar-enviar')),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('solicitar-enviar')));
    await tester.pumpAndSettle();

    expect(find.text('Solicitação enviada'), findsOneWidget);
    expect(find.text('Status: Aguardando resposta'), findsOneWidget);
    expect(
      find.textContaining('Ainda não há agendamento confirmado'),
      findsOneWidget,
    );
  });

  testWidgets('a navegação inferior abre as telas principais', (tester) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    const destinations = [
      (Icons.search_outlined, 'Buscar profissionais'),
      (Icons.favorite_border, 'Meus favoritos'),
      (Icons.calendar_month_outlined, 'Meus serviços'),
      (Icons.person_outline, 'Meu perfil'),
    ];

    for (final (icon, title) in destinations) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Meus serviços filtra pelos estados oficiais', (tester) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Meus serviços'), findsOneWidget);
    expect(find.text('Aguardando resposta'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const ValueKey('servicos-filtro-agendados')));
    await tester.pumpAndSettle();

    expect(find.text('Aceita e agendada'), findsOneWidget);
    expect(find.text('Aguardando resposta'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('servicos-filtro-aguardando')));
    await tester.pumpAndSettle();

    expect(find.text('Aguardando resposta'), findsAtLeastNWidgets(1));
    expect(find.text('Aceita e agendada'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('servicos-filtro-historico')));
    await tester.pumpAndSettle();

    expect(find.text('Conclusão confirmada'), findsOneWidget);
    expect(find.text('Recusada'), findsOneWidget);
    expect(find.text('Aguardando resposta'), findsNothing);
  });

  testWidgets('Meus serviços abre detalhes de uma solicitação', (tester) async {
    await tester.pumpWidget(const ConectaLarApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('servico-1001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('servico-1001')));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do serviço'), findsOneWidget);
    expect(find.text('Solicitação #1001'), findsOneWidget);
    expect(find.text('Aguardando resposta'), findsOneWidget);
    expect(find.textContaining('pagamento fora do app'), findsOneWidget);
  });

  testWidgets('a Home se adapta sem overflow em vários tamanhos', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 360.0, 390.0, 412.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(const ConectaLarApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Largura: $width px');
    }
  });

  testWidgets('a Home apresenta um estado vazio sem dados', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(loadContent: () async => const HomeContent())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma categoria disponível.'), findsOneWidget);
    expect(
      find.text('Nenhum profissional disponível no momento.'),
      findsOneWidget,
    );
  });

  testWidgets('a Home mostra uma mensagem amigável se o carregamento falhar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          loadContent: () async => throw Exception('detalhe interno'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar a página inicial. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('detalhe interno'), findsNothing);
  });

  testWidgets('todas as rotas registradas abrem uma tela', (tester) async {
    await tester.pumpWidget(const ConectaLarApp());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    for (final route in AppRoutes.routes.keys.where(
      (route) => route != AppRoutes.home,
    )) {
      final navigation = navigator.pushNamed<void>(route);
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget, reason: route);
      navigator.pop();
      await tester.pumpAndSettle();
      await navigation;
    }
  });
}
