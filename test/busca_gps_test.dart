import 'dart:convert';

import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/busca/busca_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/device_location_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeLocation implements DeviceLocationClient {
  _FakeLocation({this.error});

  final DeviceLocationException? error;
  int appSettingsCalls = 0;

  @override
  Future<DevicePosition> currentPosition() async {
    if (error != null) throw error!;
    return const DevicePosition(
      latitude: -23.5505199,
      longitude: -46.6333088,
      accuracyMeters: 30,
    );
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async => true;
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _profissional({double? distanciaKm}) => {
  'id': 7,
  'usuarioId': 17,
  'nome': 'Profissional proximo',
  'descricao': 'Atendimento residencial seguro e cuidadoso.',
  'bairro': 'Centro',
  'cidade': 'Sao Paulo',
  'uf': 'SP',
  'raioAtendimentoKm': 25,
  'latitudeAproximada': -23.55,
  'longitudeAproximada': -46.63,
  'distanciaKm': distanciaKm,
  'precoInicial': 90,
  'verificado': true,
  'servicos': const [],
};

Future<void> _abrirBusca(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const BuscaPage()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GPS usa POST, arredonda coordenadas e aplica o raio escolhido', (
    tester,
  ) async {
    Map<String, dynamic>? body;
    final location = _FakeLocation();
    AppServices.instance = AppServices(
      deviceLocation: location,
      api: ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/categorias') {
            return _json({'categorias': <Object>[]});
          }
          if (request.method == 'POST' &&
              request.url.path == '/profissionais/busca') {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return _json({
              'profissionais': [_profissional(distanciaKm: 1.2)],
            });
          }
          return _json({
            'profissionais': [_profissional()],
          });
        }),
      ),
    );

    await _abrirBusca(tester);
    await tester.tap(find.byKey(const ValueKey('busca-usar-gps')));
    await tester.pumpAndSettle();

    expect(body?['latitude'], -23.5505);
    expect(body?['longitude'], -46.6333);
    expect(body?['raioKm'], 25);
    await tester.scrollUntilVisible(
      find.text('Profissional proximo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('1,2 km'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('busca-raio-10')));
    await tester.pumpAndSettle();
    expect(body?['raioKm'], 10);
  });

  testWidgets('permissao permanente negada oferece as configuracoes do app', (
    tester,
  ) async {
    final location = _FakeLocation(
      error: const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
        'Libere a localizacao nas configuracoes do aplicativo.',
      ),
    );
    AppServices.instance = AppServices(
      deviceLocation: location,
      api: ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/categorias') {
            return _json({'categorias': <Object>[]});
          }
          return _json({'profissionais': <Object>[]});
        }),
      ),
    );

    await _abrirBusca(tester);
    await tester.tap(find.byKey(const ValueKey('busca-usar-gps')));
    await tester.pumpAndSettle();

    expect(
      find.text('Libere a localizacao nas configuracoes do aplicativo.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('busca-configuracao-gps')));
    await tester.pump();
    expect(location.appSettingsCalls, 1);
  });
}
