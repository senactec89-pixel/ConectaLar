import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/models/profissional.dart';
import 'package:conectarlar_app/screens/profissional/perfil_profissional_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

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
        final resumo = find.byKey(const ValueKey('perfil-resumo'));
        await tester.ensureVisible(resumo);
        await tester.pumpAndSettle();
        for (final texto in [
          'Preço inicial',
          r'R$ 180,00',
          '2 ofertas ativas',
        ]) {
          final informacao = find.descendant(
            of: resumo,
            matching: find.text(texto),
          );
          expect(informacao, findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(informacao).didExceedMaxLines,
            isFalse,
          );
        }
        if (escala == 1) {
          expect(tester.getSize(resumo).height, lessThan(110));
        }
        expect(tester.takeException(), isNull, reason: '$largura px, $escala×');
      }
    }
  });

  testWidgets(
    'atalhos preservam avaliações e ofertas sem liberar perfil pendente',
    (tester) async {
      var consultas = 0;
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path == '/profissionais/44/avaliacoes') {
            consultas++;
            return jsonResponse({
              'resumo': {'notaMedia': 4.8, 'quantidadeAvaliacoes': 1},
              'avaliacoes': [
                {
                  'nota': 5,
                  'comentario': 'Atendimento cuidadoso.',
                  'criadoEm': '2026-10-12T12:00:00Z',
                },
              ],
            });
          }
          return null;
        },
      );
      const profissional = Profissional(
        id: 44,
        usuarioId: 144,
        nome: 'Maria Eduarda de Almeida e Souza',
        descricao:
            'Instalação e manutenção residencial com atendimento na região.',
        bairro: 'Jardim das Flores',
        precoInicial: 80,
        verificado: true,
        servicos: ['Nome antigo do catálogo'],
        ofertas: [
          OfertaProfissional(
            id: 501,
            nome: 'Instalação de equipamentos residenciais',
            precoInicial: 250,
          ),
          OfertaProfissional(
            id: 502,
            nome: 'Manutenção de equipamentos residenciais',
          ),
        ],
      );
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final antes = consultas;
        Object? argumento;
        await abrirFrontend(
          tester,
          AppRoutes.perfilProfissional,
          arguments: profissional,
          width: width,
          textScale: 2,
          overrides: {
            AppRoutes.solicitarServico: (context) {
              argumento = ModalRoute.of(context)!.settings.arguments;
              return const Scaffold(body: Text('Formulário de solicitação'));
            },
          },
        );
        expect(consultas, antes + 1);
        for (final atalho in [
          ('servicos', 'Serviços oferecidos'),
          ('avaliacoes', 'Avaliações de clientes'),
          ('sobre', 'Sobre o profissional'),
        ]) {
          final botao = find.byKey(ValueKey('perfil-atalho-${atalho.$1}'));
          await tester.ensureVisible(botao);
          await tester.pumpAndSettle();
          expect(tester.getSize(botao).height, greaterThanOrEqualTo(48));
          await tester.tap(botao);
          await tester.pumpAndSettle();
          expect(find.text(atalho.$2).hitTestable(), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '$width: ${atalho.$1}',
          );
        }
        expect(
          consultas,
          antes + 1,
          reason: 'Navegar nas seções não refaz a consulta.',
        );
        expect(find.text('A partir de R\$ 250,00'), findsOneWidget);
        expect(find.text('Preço inicial sob consulta'), findsOneWidget);
        expect(find.text('Nome antigo do catálogo'), findsNothing);
        final solicitar = find.byKey(
          const ValueKey('perfil-solicitar-servico'),
        );
        expect(solicitar.hitTestable(), findsOneWidget);
        await tester.tap(solicitar);
        await tester.pumpAndSettle();
        expect(argumento, isNull);
        expect(tester.widget<FilledButton>(solicitar).onPressed, isNull);
        expect(find.text('Habilitação pendente'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'perfil sem foto ou preços por oferta mantém leitura e valores reais',
    (tester) async {
      await configurarFrontend();
      const profissional = Profissional(
        id: 44,
        usuarioId: 144,
        nome: 'Novo profissional',
        descricao: 'Atendimento residencial',
        bairro: 'Jardim das Flores',
        fotoAsset: 'assets/images/home/foto-inexistente.png',
        precoInicial: 80,
        servicos: [
          'Instalação de equipamentos residenciais com nome longo',
          'Reparos',
        ],
      );
      await abrirFrontend(
        tester,
        AppRoutes.perfilProfissional,
        arguments: profissional,
        width: 360,
        textScale: 2,
      );
      expect(find.text('N'), findsOneWidget);
      expect(find.text('Documentos verificados'), findsNothing);
      expect(find.text('Preço inicial sob consulta'), findsNWidgets(2));
      expect(find.text('A partir de R\$ 80,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('perfil público preserva ações conforme o papel autenticado', (
    tester,
  ) async {
    const profissional = Profissional(
      id: 44,
      usuarioId: 144,
      nome: 'Profissional',
      descricao: 'Atendimento residencial',
      bairro: 'Centro',
    );
    for (final papel in ['profissional', 'administrador']) {
      await configurarFrontend(papel: papel);
      await tester.pumpWidget(const SizedBox.shrink());
      await abrirFrontend(
        tester,
        AppRoutes.perfilProfissional,
        arguments: profissional,
        width: 360,
        textScale: 2,
      );
      expect(
        find.byKey(const ValueKey('perfil-solicitar-servico')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('perfil-favorito-44')), findsNothing);
      expect(
        find.byKey(const ValueKey('perfil-atalho-servicos')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      AppServices.instance.api.close();
    }
  });

  testWidgets('falha nos favoritos não impede abrir o perfil público', (
    tester,
  ) async {
    var falharFavoritos = true;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/clientes/me/favoritos/1' &&
            !falharFavoritos) {
          return jsonResponse({'favorito': true});
        }
        if (request.url.path == '/clientes/me/favoritos/1' && falharFavoritos) {
          return jsonResponse({'message': 'Falha temporária'}, 503);
        }
        return null;
      },
    );
    final profissional = const Profissional(
      id: 1,
      usuarioId: 101,
      nome: 'Carlos Silva',
      descricao: 'Atendimento residencial',
      bairro: 'Centro',
    );
    await abrirFrontend(
      tester,
      AppRoutes.perfilProfissional,
      arguments: profissional,
    );

    expect(find.text('Carlos Silva'), findsOneWidget);
    expect(
      find.text('Não foi possível verificar seus favoritos.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('perfil-solicitar-servico')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('perfil-favorito-1')), findsNothing);

    falharFavoritos = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível verificar seus favoritos.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('perfil-favorito-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
