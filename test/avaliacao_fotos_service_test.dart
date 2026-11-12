import 'dart:convert';
import 'dart:typed_data';

import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/avaliacao_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'upload de foto usa multipart autenticado sem publicar URL de storage',
    () async {
      final image = Uint8List.fromList([0xff, 0xd8, 0xff, 0x01, 0x02]);
      var checked = false;
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = String.fromCharCodes(request.bodyBytes);
          expect(body, contains('name="arquivo"'));
          expect(body, contains('filename="prova.jpg"'));
          for (final byte in image) {
            expect(request.bodyBytes, contains(byte));
          }
          checked = true;
          return httpResponse({
            'foto': {'id': 17, 'mimeType': 'image/jpeg'},
          });
        }),
      )..definirToken('test-token');
      addTearDown(api.close);

      final fotoId = await AvaliacaoService(
        api,
      ).enviarFoto(solicitacaoId: 5, nomeArquivo: 'prova.jpg', bytes: image);

      expect(checked, isTrue);
      expect(fotoId, 17);
    },
  );

  test(
    'envio da avaliacao associa somente IDs temporarios recebidos da API',
    () async {
      Map<String, dynamic>? payload;
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return httpResponse({
            'avaliacao': {'id': 4},
          });
        }),
      )..definirToken('test-token');
      addTearDown(api.close);

      await AvaliacaoService(
        api,
      ).avaliarProfissional(solicitacaoId: 5, nota: 5, fotoIds: const [17, 18]);

      expect(payload, {
        'nota': 5,
        'fotoIds': [17, 18],
      });
    },
  );
}

http.Response httpResponse(Object value) => http.Response(
  jsonEncode(value),
  201,
  headers: const {'content-type': 'application/json'},
);
