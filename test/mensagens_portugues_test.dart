import 'package:conectarlar_app/services/google_identity_service.dart';
import 'package:conectarlar_app/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mensagem de CEP preserva validação e acentuação', () {
    expect(validarCepOpcional('123'), 'Informe um CEP com 8 dígitos.');
    expect(validarCepOpcional('12345-678'), isNull);
    expect(validarCepOpcional(''), isNull);
  });

  test('login Google sem configuração informa o problema em português', () {
    final google = PluginGoogleIdentityClient();
    if (!google.configured) {
      expect(
        () => google.initialize(),
        throwsA(
          isA<GoogleIdentityException>().having(
            (erro) => erro.message,
            'mensagem',
            'O login com Google ainda não foi configurado neste aplicativo.',
          ),
        ),
      );
    }
  });
}
