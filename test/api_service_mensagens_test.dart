import 'package:conectarlar_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/frontend_helpers.dart';

Future<ApiException> _erroHttp({
  required String endpoint,
  required int status,
  required Object resposta,
}) async {
  final api = ApiService(
    client: MockClient((_) async => jsonResponse(resposta, status)),
  );
  try {
    await api.post(endpoint, body: const {});
  } on ApiException catch (error) {
    return error;
  } finally {
    api.close();
  }
  throw StateError('A solicitação deveria ter falhado.');
}

void main() {
  test(
    'mensagem técnica do servidor vira orientação segura e localizada',
    () async {
      final error = await _erroHttp(
        endpoint: 'admin/usuarios',
        status: 500,
        resposta: {
          'message':
              'QueryFailedError: ER_DUP_ENTRY at /srv/conectalar/node_modules/db',
        },
      );

      expect(
        error.message,
        'Não foi possível concluir agora. Tente novamente em instantes.',
      );
      expect(error.statusCode, 500);
    },
  );

  test('mensagem específica e legível da API continua disponível', () async {
    final error = await _erroHttp(
      endpoint: 'categorias',
      status: 409,
      resposta: {'message': 'Já existe uma categoria com este nome.'},
    );

    expect(error.message, 'Já existe uma categoria com este nome.');
  });

  test('resposta técnica no login não diz que uma sessão expirou', () async {
    final error = await _erroHttp(
      endpoint: 'auth/login',
      status: 401,
      resposta: {'message': 'UnauthorizedException'},
    );

    expect(
      error.message,
      'Não foi possível entrar. Confira seus dados e tente novamente.',
    );
  });
}
