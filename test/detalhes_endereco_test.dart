import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  final previa = FrontendPreviewClient();

  testWidgets('detalhe exibe endereço autorizado ao cliente participante', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/solicitacoes/1002'
          ? jsonResponse({'solicitacao': previa.pedidos[1]})
          : null,
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1002);

    expect(
      find.text('Rua de exemplo, 100 - Centro, Cidade de exemplo/MG'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe protege endereço sem liberação explícita', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/solicitacoes/1002'
          ? jsonResponse({
              'solicitacao': {
                ...previa.pedidos[1],
                'enderecoCompletoLiberado': false,
              },
            })
          : null,
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1002);

    expect(find.textContaining('Rua de exemplo'), findsNothing);
    expect(
      find.text('Centro. Endereço completo não disponível para esta conta.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe não exibe endereço para não participante', (
    tester,
  ) async {
    await configurarFrontend(
      responder: (request) async => request.url.path == '/solicitacoes/1002'
          ? jsonResponse({
              'solicitacao': {
                ...previa.pedidos[1],
                'cliente': {'id': 999},
              },
            })
          : null,
    );
    await abrirFrontend(tester, AppRoutes.detalhesServico, arguments: 1002);

    expect(find.textContaining('Rua de exemplo'), findsNothing);
    expect(
      find.text('Centro. Endereço completo não disponível para esta conta.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
