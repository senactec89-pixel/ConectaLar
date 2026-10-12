import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/models/profissional.dart';
import 'package:conectarlar_app/screens/profissional/perfil_profissional_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('perfil público mantém selo e solicitação legíveis no mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    AppServices.instance = AppServices(modoDemo: true);

    const profissional = Profissional(
      id: 1,
      usuarioId: 101,
      nome: 'Maria Eduarda de Almeida e Souza',
      descricao: 'Especialista em instalações e manutenção residencial',
      bairro: 'Jardim das Flores',
      precoInicial: 180,
      categoriaIds: [1],
      verificado: true,
      notaMedia: 4.9,
      quantidadeAvaliacoes: 1234,
      servicos: ['Instalações elétricas', 'Manutenção residencial'],
    );

    for (final largura in [360.0, 390.0, 412.0]) {
      for (final escala in [1.0, 1.4, 2.0]) {
        tester.view.physicalSize = Size(largura, 844);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$largura-$escala'),
            theme: AppTheme.light,
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: RouteSettings(
                name: settings.name,
                arguments: profissional,
              ),
              builder: (_) => const PerfilProfissionalPage(),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final selo = find.text('Documentos verificados');
        expect(selo, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(selo).didExceedMaxLines,
          isFalse,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('perfil-favorito-1'))).width,
          greaterThanOrEqualTo(48),
        );
        final solicitar = find.byKey(
          const ValueKey('perfil-solicitar-servico'),
        );
        expect(tester.getSize(solicitar).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });
}
