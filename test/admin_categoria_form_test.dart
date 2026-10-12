import 'dart:async';
import 'dart:convert';

import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/screens/admin/categoria_form_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:conectarlar_app/utils/categoria_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/frontend_helpers.dart';

const _nome = ValueKey('categoria-form-nome');
const _salvar = ValueKey('categoria-form-salvar');
const _ativo = ValueKey('categoria-form-ativo');
const _icones = ValueKey('categoria-form-icones');

Future<void> _abrir(
  WidgetTester tester, {
  Map<String, dynamic>? categoria,
  double width = 390,
  double textScale = 1,
}) => abrirFrontend(
  tester,
  '/teste-categoria',
  width: width,
  textScale: textScale,
  overrides: {
    '/teste-categoria': (_) => CategoriaFormPage(categoria: categoria),
  },
);

Future<void> _selecionarIcone(WidgetTester tester, String id) async {
  final icone = find.byKey(ValueKey('categoria-icone-$id'));
  await tester.ensureVisible(icone);
  await tester.pumpAndSettle();
  await tester.tap(icone);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('edição preenche campos e mantém IDs do contrato ao salvar', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    String? method;
    String? path;
    await configurarFrontend(
      papel: 'administrador',
      responder: (request) async {
        if (!request.url.path.startsWith('/categorias')) {
          return null;
        }
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        method = request.method;
        path = request.url.path;
        return jsonResponse({
          'categoria': {'id': 8, ...payload!},
        });
      },
    );
    Object? resultado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                resultado = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const CategoriaFormPage(
                      categoria: {
                        'id': 8,
                        'nome': 'Hidráulica',
                        'icone': 'plumbing',
                        'ativo': false,
                      },
                    ),
                  ),
                );
              },
              child: const Text('Lista de categorias'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lista de categorias'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(_nome)).controller!.text,
      'Hidráulica',
    );
    expect(tester.widget<SwitchListTile>(find.byKey(_ativo)).value, isFalse);
    await tester.enterText(find.byKey(_nome), '  Instalações elétricas  ');
    await tester.ensureVisible(find.byKey(_icones));
    await tester.tap(find.byKey(_icones));
    await tester.pumpAndSettle();
    await _selecionarIcone(tester, 'electrical_services');
    await tester.ensureVisible(find.byKey(_ativo));
    await tester.tap(find.byKey(_ativo));
    await tester.ensureVisible(find.byKey(_salvar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_salvar));
    await tester.pumpAndSettle();
    expect(method, 'PATCH');
    expect(path, '/categorias/8');
    expect(payload, {
      'nome': 'Instalações elétricas',
      'icone': 'electrical_services',
      'ativo': true,
    });
    expect(resultado, isTrue);
    expect(find.text('Lista de categorias'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'criação bloqueia envios simultâneos e preserva formulário no erro',
    (tester) async {
      final resposta = Completer<http.Response>();
      final payloads = <Map<String, dynamic>>[];
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path != '/categorias') {
            return null;
          }
          expect(request.method, 'POST');
          payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
          return resposta.future;
        },
      );
      await _abrir(tester);
      await tester.enterText(find.byKey(_nome), 'Jardinagem');
      await tester.ensureVisible(find.byKey(_icones));
      await tester.tap(find.byKey(_icones));
      await tester.pumpAndSettle();
      await _selecionarIcone(tester, 'grass');
      await tester.ensureVisible(find.byKey(_salvar));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_salvar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Salvando...'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byKey(_nome)).enabled, isFalse);
      expect(
        tester.widget<SwitchListTile>(find.byKey(_ativo)).onChanged,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(_salvar)).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(_salvar));
      await tester.pump(const Duration(milliseconds: 100));
      expect(payloads, [
        {'nome': 'Jardinagem', 'icone': 'grass', 'ativo': true},
      ]);
      resposta.complete(jsonResponse({'message': 'Falha de rede.'}, 503));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byKey(_nome)).controller!.text,
        'Jardinagem',
      );
      expect(
        tester.widget<FilledButton>(find.byKey(_salvar)).onPressed,
        isNotNull,
      );
      expect(find.text('Falha de rede.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [409, 403]) {
    testWidgets(
      'erro $status mantém nome, ícone e situação sem fechar a tela',
      (tester) async {
        var chamadas = 0;
        await configurarFrontend(
          papel: 'administrador',
          responder: (request) async {
            if (request.url.path != '/categorias/8') {
              return null;
            }
            chamadas++;
            return jsonResponse({'message': 'Falha'}, status);
          },
        );
        await _abrir(
          tester,
          categoria: {
            'id': 8,
            'nome': 'Pintura',
            'icone': 'format_paint',
            'ativo': false,
          },
        );
        await tester.ensureVisible(find.byKey(_salvar));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_salvar));
        await tester.pumpAndSettle();
        expect(chamadas, 1);
        expect(
          find.text(
            status == 409
                ? 'Já existe uma categoria com este nome. Escolha outro nome.'
                : 'Sua conta não tem permissão para alterar categorias.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(find.byKey(_nome)).controller!.text,
          'Pintura',
        );
        expect(
          tester.widget<SwitchListTile>(find.byKey(_ativo)).value,
          isFalse,
        );
        expect(
          tester.widget<FilledButton>(find.byKey(_salvar)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('conta cliente não acessa formulário de categoria', (
    tester,
  ) async {
    var chamadas = 0;
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path.startsWith('/categorias')) {
          chamadas++;
        }
        return null;
      },
    );
    await _abrir(tester);
    expect(find.text('Área indisponível para esta conta'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(chamadas, 0);
  });

  testWidgets(
    'ícones, prévia e validação cabem em três larguras com texto 200% e teclado',
    (tester) async {
      var chamadas = 0;
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path.startsWith('/categorias')) {
            chamadas++;
          }
          return null;
        },
      );
      addTearDown(tester.view.resetViewInsets);
      for (final width in [360.0, 390.0, 412.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _abrir(tester, width: width, textScale: 2);
        await tester.ensureVisible(find.byKey(_nome));
        await tester.enterText(find.byKey(_nome), 'A');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(_icones));
        await tester.tap(find.byKey(_icones));
        await tester.pumpAndSettle();
        for (final option in categoriaIconOptions) {
          await _selecionarIcone(tester, option.id);
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.byKey(_salvar));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(_salvar)).height,
          greaterThanOrEqualTo(52),
        );
        await tester.tap(find.byKey(_salvar));
        await tester.pumpAndSettle();
        expect(
          find.text('Informe um nome entre 2 e 80 caracteres.'),
          findsOneWidget,
        );
        expect(chamadas, 0);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      }
    },
  );

  testWidgets(
    'ícone legado desconhecido exige seleção e não muda silenciosamente',
    (tester) async {
      var chamadas = 0;
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path.startsWith('/categorias')) {
            chamadas++;
          }
          return null;
        },
      );
      await _abrir(
        tester,
        categoria: {
          'id': 8,
          'nome': 'Legado',
          'icone': 'icone_desconhecido',
          'ativo': true,
        },
      );
      await tester.ensureVisible(find.byKey(_salvar));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_salvar));
      await tester.pumpAndSettle();
      expect(find.text('Selecione um ícone do catálogo.'), findsOneWidget);
      expect(chamadas, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
