import 'dart:convert';

import 'package:conectarlar_app/app/app.dart';
import 'package:conectarlar_app/models/home_content.dart';
import 'package:conectarlar_app/screens/home/home_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  test('URL padrão respeita a plataforma e a configuração explícita', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const configurada = String.fromEnvironment('CONECTALAR_API_BASE_URL');
    for (final plataforma in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = plataforma;
      expect(
        AppConstants.apiBaseUrl,
        configurada.isNotEmpty
            ? configurada
            : plataforma == TargetPlatform.android
            ? 'http://10.0.2.2:3012'
            : 'http://127.0.0.1:3012',
      );
    }
  });

  test(
    'prévia não restaura, substitui ou remove a sessão real salva',
    () async {
      const key = 'conectalar.auth.session.v1';
      final sessao = jsonEncode({
        'accessToken': 'token-real-simulado-no-teste',
        'usuario': {'id': 44, 'tipo': 'cliente', 'nome': 'Conta de teste'},
      });
      SharedPreferences.setMockInitialValues({key: sessao});
      AppServices.instance = AppServices(
        modoDemo: true,
        papelDemo: 'administrador',
      );
      await AppServices.instance.inicializar();
      expect(AppServices.instance.auth.usuarioAtual?['tipo'], 'administrador');
      expect((await SharedPreferences.getInstance()).getString(key), sessao);
      expect(
        (await AppServices.instance.admin.painel())['catalogo'],
        isNotNull,
      );
      await expectLater(
        AppServices.instance.admin.salvarCategoria(
          nome: 'Teste',
          icone: 'home_repair',
          ativo: true,
        ),
        throwsA(isA<ApiException>()),
      );
      await AppServices.instance.auth.logout();
      expect((await SharedPreferences.getInstance()).getString(key), sessao);
    },
  );

  test('uso real continua restaurando a sessão salva', () async {
    SharedPreferences.setMockInitialValues({
      'conectalar.auth.session.v1': jsonEncode({
        'accessToken': 'token-teste',
        'usuario': {'id': 44, 'tipo': 'cliente'},
      }),
    });
    AppServices.instance = AppServices(modoDemo: false);
    await AppServices.instance.inicializar();
    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(AppServices.instance.auth.usuarioAtual?['id'], 44);
  });

  testWidgets('prévia abre cliente, profissional, empresa e admin sem API', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final papel in [
      'cliente',
      'profissional',
      'empresa',
      'administrador',
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      AppServices.instance.api.close();
      AppServices.instance = AppServices(modoDemo: true, papelDemo: papel);
      await AppServices.instance.inicializar();
      await tester.pumpWidget(const ConectaLarApp());
      await tester.pumpAndSettle();
      expect(tester.widget<Banner>(find.byType(Banner)).message, 'DEMO');
      expect(find.text('Tentar novamente'), findsNothing);
      expect(find.text('Acesso restrito'), findsNothing);
      expect(
        find.text(switch (papel) {
          'cliente' => 'Categorias',
          'administrador' => 'Visão geral',
          _ => 'Próximos atendimentos',
        }),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: papel);
    }
  });

  testWidgets('Home informa falha de conexão e consegue tentar novamente', (
    tester,
  ) async {
    var tentativas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          loadContent: () async {
            if (++tentativas == 1) {
              throw http.ClientException('detalhe interno');
            }
            return const HomeContent();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível conectar ao serviço'),
      findsOneWidget,
    );
    expect(find.text('detalhe interno'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Categorias'), findsOneWidget);
    expect(tentativas, 2);
    expect(tester.takeException(), isNull);
  });
}
