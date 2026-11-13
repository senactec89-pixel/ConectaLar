import 'package:conectarlar_app/services/api_mappers.dart';
import 'package:conectarlar_app/widgets/escopo_servico_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'interpreta escopo da oferta e preserva compatibilidade com dados antigos',
    () {
      final profissional = profissionalFromApi({
        'servicos': [
          {
            'id': 1,
            'nome': 'Limpeza',
            'inclui': ['Pisos'],
            'naoInclui': ['Altura'],
            'opcionais': ['Janelas'],
          },
          {'id': 2, 'nome': 'Oferta anterior'},
        ],
      });
      expect(profissional.ofertas.first.inclui, ['Pisos']);
      expect(profissional.ofertas.first.naoInclui, ['Altura']);
      expect(profissional.ofertas.first.opcionais, ['Janelas']);
      expect(profissional.ofertas.last.inclui, isEmpty);
    },
  );

  testWidgets('escopo é legível com texto ampliado e distingue opcionais', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: EscopoServicoView(
                titulo: 'Detalhes da oferta',
                inclui: ['Limpeza de pisos acessíveis'],
                naoInclui: ['Trabalho em altura'],
                opcionais: ['Limpeza de janelas'],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Inclui'), findsOneWidget);
    expect(find.text('Não inclui'), findsOneWidget);
    expect(find.text('Opcionais a combinar'), findsOneWidget);
    expect(
      find.text('Opcionais devem ser combinados com o profissional.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
