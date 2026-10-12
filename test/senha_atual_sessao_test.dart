import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frontend_helpers.dart';

void main() {
  tearDown(() => AppServices.instance.api.close());

  test('senha atual invalida nao derruba a sessao autenticada', () async {
    await configurarFrontend(
      responder: (request) async {
        if (request.url.path == '/auth/senha') {
          return jsonResponse({
            'code': 'SENHA_ATUAL_INVALIDA',
            'message': 'Senha atual invalida.',
          }, 401);
        }
        return null;
      },
    );

    await expectLater(
      AppServices.instance.auth.alterarSenha(
        senhaAtual: 'SenhaErrada123!',
        novaSenha: 'SenhaNova123!',
      ),
      throwsA(isA<ApiException>()),
    );

    expect(AppServices.instance.auth.autenticado, isTrue);
    expect(AppServices.instance.auth.sessaoExpirada, isFalse);
  });
}
