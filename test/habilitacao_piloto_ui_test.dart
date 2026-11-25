import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/screens/admin/dossie_profissional_page.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets(
    'iniciante exige confirmacao explicita com tela estreita e teclado',
    (tester) async {
      Map<String, dynamic>? salvo;
      await configurarFrontend(
        papel: 'profissional',
        responder: (request) async {
          if (request.url.path == '/categorias') {
            return jsonResponse({
              'categorias': [
                {'id': 5, 'nome': 'Manutencao'},
              ],
            });
          }
          if (request.url.path == '/categorias/5/servicos') {
            return jsonResponse({
              'servicos': [
                {
                  'id': 12,
                  'nome': 'Reparo de torneira',
                  'politicaPiloto': 'iniciante_ou_experiencia',
                  'criterioPiloto':
                      'Tarefa simples sem intervencao em tubulacao embutida.',
                },
              ],
            });
          }
          if (request.url.path != '/profissionais/me/servicos') return null;
          if (request.method == 'PUT') {
            salvo = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({'servicos': (salvo!['servicos'] as List)});
          }
          return jsonResponse({'servicos': []});
        },
      );
      await abrirFrontend(
        tester,
        AppRoutes.servicosProfissional,
        width: 320,
        textScale: 2,
      );
      tester.view.physicalSize = const Size(320, 700);

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manutencao').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reparo de torneira').last);
      await tester.pumpAndSettle();
      final experiencia = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(experiencia);
      await tester.pumpAndSettle();
      await tester.tap(experiencia);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sou iniciante nesta tarefa'));
      await tester.pumpAndSettle();

      final formacao = find.byKey(const Key('formacao-informada-piloto'));
      await tester.ensureVisible(formacao);
      await tester.enterText(
        formacao,
        'Curso livre de limpeza, Escola Exemplo, 2025',
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();

      final confirmacao = find.byType(CheckboxListTile);
      final scrollDialogo = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        confirmacao,
        120,
        scrollable: scrollDialogo,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(confirmacao).value, isFalse);
      final preco = find.byKey(const Key('preco-inicial-piloto'));
      await tester.scrollUntilVisible(preco, 120, scrollable: scrollDialogo);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(preco, 120, scrollable: scrollDialogo);
      await tester.tap(preco);
      await tester.enterText(preco, '100');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        confirmacao,
        120,
        scrollable: scrollDialogo,
      );
      await tester.pumpAndSettle();
      expect(confirmacao.hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Salvar'),
        120,
        scrollable: scrollDialogo,
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(salvo, isNull);

      await tester.scrollUntilVisible(
        confirmacao,
        120,
        scrollable: scrollDialogo,
      );
      await tester.pumpAndSettle();
      await tester.tap(confirmacao);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(
        (salvo!['servicos'] as List).single['inicianteConfirmadoPiloto'],
        true,
      );
      expect(
        (salvo!['servicos'] as List).single['formacaoInformadaPiloto'],
        'Curso livre de limpeza, Escola Exemplo, 2025',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dossie e revisao continuam acessiveis em tela estreita com texto ampliado',
    (tester) async {
      await configurarFrontend(
        papel: 'administrador',
        responder: (request) async {
          if (request.url.path != '/admin/profissionais/10/dossie') return null;
          return jsonResponse({
            'profissional': {
              'id': 10,
              'nome':
                  'Profissional de teste com nome extenso para validar quebra de linha',
              'habilitacao': {'estado': 'pendente', 'etapas': []},
              'ofertas': [
                {
                  'id': 4,
                  'nome':
                      'Reparo residencial simples em torneira e sifao aparente',
                  'ativo': true,
                  'categoria': 'Hidraulica',
                  'politicaPiloto': 'iniciante_ou_experiencia',
                  'criterioPiloto':
                      'Tarefa simples; nao inclui tubulacao embutida ou trabalho em altura.',
                  'descricaoTarefa':
                      'Ajustes em torneiras e sifoes aparentes de facil acesso.',
                  'inclusoesTarefa':
                      'Apertos e substituicao simples de vedacao.',
                  'exclusoesTarefa':
                      'Sem abertura de paredes ou alteracao de tubulacao.',
                  'inclusoesDeclaradas': ['Torneira acessivel'],
                  'exclusoesDeclaradas': ['Tubulacao embutida'],
                  'opcionaisDeclarados': [],
                  'nivelExperienciaPiloto': 'iniciante',
                  'inicianteConfirmadoPiloto': true,
                  'revisaoExperienciaEstado': 'pendente',
                  'relatoExperienciaPiloto': null,
                  'formacaoInformadaPiloto': 'Curso informado, não verificado',
                  'frequenciaExperienciaPiloto': null,
                },
              ],
            },
            'documentos': [],
            'paginacao': {'totalPaginas': 1},
          });
        },
      );
      await abrirFrontend(
        tester,
        '/dossie-piloto-teste',
        width: 320,
        textScale: 2,
        overrides: {
          '/dossie-piloto-teste': (_) =>
              const DossieProfissionalPage(profissionalId: 10),
        },
      );
      tester.view.physicalSize = const Size(320, 700);
      final revisao = find.byType(PopupMenuButton<String>);
      await tester.scrollUntilVisible(
        revisao,
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(revisao.hitTestable(), findsOneWidget);
      expect(find.textContaining('Confirma'), findsOneWidget);
      expect(
        find.textContaining('Curso/formação informado (não verificado)'),
        findsOneWidget,
      );
      await tester.tap(revisao);
      await tester.pumpAndSettle();
      expect(find.textContaining('Aprovar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
