import 'dart:convert';

import 'package:conectarlar_app/app/routes.dart';
import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/services/api_mappers.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  testWidgets('novo serviço exige duração e envia o valor preenchido', (
    tester,
  ) async {
    Map<String, dynamic>? enviado;
    await configurarFrontend(
      papel: 'profissional',
      responder: (request) async {
        if (request.url.path.endsWith('/me/servicos')) {
          if (request.method == 'PUT') {
            enviado = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return jsonResponse({'servicos': []});
        }
        return null;
      },
    );
    await abrirFrontend(
      tester,
      AppRoutes.servicosProfissional,
      width: 360,
      textScale: 2,
    );
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do serviço'),
      'Instalação de teste',
    );
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe de 1 a 1440 minutos.'), findsOneWidget);
    expect(enviado, isNull);
    final duracao = find.byKey(const ValueKey('servico-duracao'));
    await tester.ensureVisible(duracao);
    await tester.enterText(duracao, '90');
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect((enviado!['servicos'] as List).single['duracaoMinutos'], 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sugestões usam janelas livres da API e comportam a duração inteira',
    (tester) async {
      final data = DateTime.now().add(const Duration(days: 2));
      await configurarFrontend(
        responder: (request) async {
          if (request.url.path.endsWith('/disponibilidade')) {
            return jsonResponse({
              'disponibilidades': [
                {
                  'id': 1,
                  'diaSemana': data.weekday % 7,
                  'horaInicio': '08:00',
                  'horaFim': '18:00',
                  'ativo': true,
                },
              ],
            });
          }
          if (request.url.path.endsWith('/horarios')) {
            return jsonResponse({
              'duracaoMinutos': 120,
              'intervalos': [
                {'horaInicio': '09:00', 'horaFim': '10:00'},
                {'horaInicio': '12:00', 'horaFim': '16:00'},
              ],
            });
          }
          return null;
        },
      );
      await abrirFrontend(
        tester,
        AppRoutes.solicitarServico,
        arguments: profissionalFromApi(
          FrontendPreviewClient().profissionais.first,
        ),
      );
      final campo = find.byKey(const ValueKey('solicitar-data'));
      await tester.ensureVisible(campo);
      await tester.enterText(
        campo,
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}',
      );
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((chip) => (chip.label as Text).data!)
          .toList();
      expect(labels.length, 3);
      expect(labels.any((label) => label.endsWith('09:00')), isFalse);
      expect(labels.any((label) => label.endsWith('12:00')), isTrue);
      expect(labels.any((label) => label.endsWith('15:00')), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
