import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/services/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sessão e transporte simulados somente em testes, com desvios específicos.
Future<MemorySessionStorage> configurarFrontend({
  String papel = 'cliente',
  Future<http.Response?> Function(http.Request)? responder,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sessionStorage = MemorySessionStorage();
  final preview = FrontendPreviewClient(papel: papel);
  AppServices.instance = AppServices(
    modoDemo: false,
    sessionStorage: sessionStorage,
    api: ApiService(
      client: MockClient((request) async {
        final override = await responder?.call(request);
        return override ??
            await http.Response.fromStream(await preview.send(request));
      }),
    ),
  );
  await AppServices.instance.auth.login(
    email: 'teste@example.invalid',
    senha: 'teste',
  );
  return sessionStorage;
}

Future<void> abrirFrontend(
  WidgetTester tester,
  String route, {
  Object? arguments,
  double width = 390,
  double textScale = 1,
  Map<String, WidgetBuilder> overrides = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final routes = {...AppRoutes.routes, ...overrides};
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      routes: routes,
      initialRoute: route,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: route, arguments: arguments),
          builder: routes[route]!,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}
