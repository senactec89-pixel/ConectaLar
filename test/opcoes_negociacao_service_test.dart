import 'dart:convert';

import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/categoria_service.dart';
import 'package:conectarlar_app/services/servico_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response resposta(Object dados) => http.Response(
  jsonEncode(dados),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('opcoes percorrem as paginas do catalogo', () async {
    final api = ApiService(
      client: MockClient((request) async {
        final pagina = request.url.queryParameters['pagina'];
        return resposta({
          'opcoes': [
            {'id': int.parse(pagina!), 'nome': 'Opcao $pagina'},
          ],
          'paginacao': {'temMais': pagina == '1'},
        });
      }),
    );
    addTearDown(api.close);
    final opcoes = await CategoriaService(api).opcoes(5, 12);
    expect(opcoes.map((o) => o['id']), [1, 2]);
  });

  for (final caso in ['novo', 'antigo', 'invalido']) {
    test('resposta profissional: $caso', () async {
      final chamadas = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          chamadas.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/opcoes')) {
            return resposta({
              'opcoes': caso == 'invalido'
                  ? 'erro'
                  : caso == 'novo'
                  ? [
                      {'id': 1, 'nome': 'Opcao'},
                    ]
                  : [],
            });
          }
          return resposta({'negociacaoIniciada': caso == 'novo'});
        }),
      );
      addTearDown(api.close);
      final future = ServicoService(api).aceitarOuNegociar(7);
      if (caso == 'invalido') {
        await expectLater(future, throwsFormatException);
        expect(chamadas, hasLength(1));
      } else {
        await future;
        expect(
          chamadas.last,
          caso == 'novo'
              ? 'POST /solicitacoes/7/negociacao'
              : 'PATCH /solicitacoes/7/aceitar',
        );
      }
    });
  }
}
