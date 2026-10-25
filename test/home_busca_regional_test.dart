import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/models/home_content.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  test(
    'sem endereço não consulta nem mostra a lista geral de profissionais',
    () async {
      final paths = <String>[];
      await configurarFrontend(
        responder: (request) async {
          paths.add(request.url.path);
          if (request.url.path == '/clientes/me/enderecos') {
            return jsonResponse({'enderecos': []});
          }
          return null;
        },
      );

      final content = await AppServices.instance.carregarHome();

      expect(content.regionalAddressUnavailable, isTrue);
      expect(content.nearbySearchAvailable, isFalse);
      expect(content.featuredProfessionals, isEmpty);
      expect(paths, isNot(contains('/profissionais')));
    },
  );

  test(
    'endereço sem coordenadas usa os filtros de localidade sem fallback',
    () async {
      final requests = <Uri>[];
      await configurarFrontend(
        responder: (request) async {
          requests.add(request.url);
          if (request.url.path == '/clientes/me/enderecos') {
            return jsonResponse({
              'enderecos': [
                {
                  'bairro': 'Centro',
                  'cidade': 'Campinas',
                  'uf': 'SP',
                  'principal': true,
                },
              ],
            });
          }
          if (request.url.path == '/profissionais') {
            return jsonResponse({'profissionais': []});
          }
          return null;
        },
      );

      final content = await AppServices.instance.carregarHome();
      final professionalQueries = requests
          .where((uri) => uri.path == '/profissionais')
          .toList();

      expect(content.regionalAddressUnavailable, isFalse);
      expect(content.nearbySearchAvailable, isTrue);
      expect(content.featuredProfessionals, isEmpty);
      expect(professionalQueries, hasLength(1));
      expect(professionalQueries.single.queryParameters['bairro'], 'Centro');
      expect(professionalQueries.single.queryParameters['cidade'], 'Campinas');
      expect(professionalQueries.single.queryParameters['uf'], 'SP');
    },
  );

  test(
    'endereço com coordenadas busca por raio e mantém resultado vazio',
    () async {
      final requests = <(String, Uri, String)>[];
      await configurarFrontend(
        responder: (request) async {
          requests.add((request.method, request.url, request.body));
          if (request.url.path == '/clientes/me/enderecos') {
            return jsonResponse({
              'enderecos': [
                {
                  'latitude': -22.9056,
                  'longitude': -47.0608,
                  'principal': true,
                },
              ],
            });
          }
          if (request.url.path == '/profissionais/busca') {
            return jsonResponse({'profissionais': []});
          }
          return null;
        },
      );

      final content = await AppServices.instance.carregarHome();
      final regionalRequest = requests.singleWhere(
        (request) => request.$2.path == '/profissionais/busca',
      );
      final body = jsonDecode(regionalRequest.$3) as Map<String, dynamic>;

      expect(content.featuredProfessionals, isEmpty);
      expect(content.nearbySearchAvailable, isTrue);
      expect(regionalRequest.$1, 'POST');
      expect(body['latitude'], -22.9056);
      expect(body['longitude'], -47.0608);
      expect(body['raioKm'], 50);
      expect(
        requests.where((request) => request.$2.path == '/profissionais'),
        isEmpty,
      );
    },
  );

  test(
    'falha ao consultar endereços aparece como erro, sem lista geral',
    () async {
      final paths = <String>[];
      await configurarFrontend(
        responder: (request) async {
          paths.add(request.url.path);
          if (request.url.path == '/clientes/me/enderecos') {
            return jsonResponse({'message': 'Falha temporária'}, 503);
          }
          return null;
        },
      );

      final content = await AppServices.instance.carregarHome();

      expect(content.professionalsLoadFailed, isTrue);
      expect(content.nearbySearchAvailable, isFalse);
      expect(content.featuredProfessionals, isEmpty);
      expect(paths, isNot(contains('/profissionais')));
    },
  );

  testWidgets('Home orienta a cadastrar endereço quando ele não existe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          loadContent: () async =>
              const HomeContent(regionalAddressUnavailable: true),
        ),
        routes: {
          AppRoutes.enderecos: (_) =>
              const Scaffold(body: Text('Tela de endereços')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cadastre um endereço para encontrar profissionais da sua região.',
      ),
      findsOneWidget,
    );
    final addAddress = find.text('Adicionar endereço');
    await tester.ensureVisible(addAddress);
    await tester.tap(addAddress);
    await tester.pumpAndSettle();

    expect(find.text('Tela de endereços'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'lista geral de outros perfis não é marcada como busca próxima',
    () async {
      await configurarFrontend(papel: 'profissional');

      final content = await AppServices.instance.carregarHome();

      expect(content.featuredProfessionals, isNotEmpty);
      expect(content.nearbySearchAvailable, isFalse);
    },
  );
}
