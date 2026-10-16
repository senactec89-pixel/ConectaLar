import 'package:conectarlar_app/services/session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'conectalar.auth.session.v1';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('migra a sessao legada e remove o valor sem criptografia', () async {
    SharedPreferences.setMockInitialValues({key: 'sessao-legada'});
    final storage = SecureSessionStorage();

    expect(await storage.read(key), 'sessao-legada');
    expect((await SharedPreferences.getInstance()).getString(key), isNull);
    expect(await const FlutterSecureStorage().read(key: key), 'sessao-legada');
  });

  test('grava e remove a sessao somente no armazenamento seguro', () async {
    final storage = SecureSessionStorage();

    await storage.write(key, 'sessao-segura');
    expect(await storage.read(key), 'sessao-segura');
    expect((await SharedPreferences.getInstance()).getString(key), isNull);

    await storage.delete(key);
    expect(await storage.read(key), isNull);
  });
}
