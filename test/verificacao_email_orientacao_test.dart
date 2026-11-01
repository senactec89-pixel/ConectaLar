import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/auth/verificacao_email_page.dart';
import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/frontend_helpers.dart';

void main() {
  testWidgets('orientação de e-mail e reenvio cabem com texto ampliado', (
    tester,
  ) async {
    var reenvios = 0;
    AppServices.instance = AppServices(
      api: ApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/auth/email/verificacao/enviar');
          reenvios++;
          return jsonResponse({'ok': true});
        }),
      ),
    );
    addTearDown(() => AppServices.instance.api.close());
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final width in [360.0, 390.0, 412.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: VerificacaoEmailPage(key: ValueKey(width)),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final ajuda = find.text(
        'Não encontrou o e-mail? Confira a pasta de spam ou solicite outro código abaixo.',
      );
      await tester.scrollUntilVisible(
        ajuda,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.renderObject<RenderParagraph>(ajuda).didExceedMaxLines,
        isFalse,
      );
      final reenviar = find.byKey(const ValueKey('email-verificacao-reenviar'));
      await tester.scrollUntilVisible(
        reenviar,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(reenviar);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Enviamos um novo código. Confira sua caixa de entrada e spam.',
        ),
        findsOneWidget,
      );
      expect(find.text('Segurança e privacidade da conta'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }
    expect(reenvios, 3);
  });
}
