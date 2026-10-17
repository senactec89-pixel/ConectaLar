// Fixtures exclusivas da galeria visual. Não acessam rede nem dados reais.
import 'dart:convert';
import 'dart:typed_data';

import 'package:conectarlar_app/data/frontend_preview_client.dart';
import 'package:conectarlar_app/screens/home/home_mock_data.dart';
import 'package:http/http.dart' as http;

class VisualPreviewClient extends FrontendPreviewClient {
  VisualPreviewClient({required super.papel});

  @override
  List<Map<String, dynamic>> get profissionais {
    final dados = super.profissionais;
    return [
      for (var i = 0; i < dados.length; i++)
        {
          ...dados[i],
          'fotoPerfilUrl': Uri.base
              .resolve(
                'assets/${HomeMockData.content.featuredProfessionals[i].fotoAsset}',
              )
              .toString(),
        },
    ];
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'GET' &&
        RegExp(r'^/documentos-verificacao/\d+/arquivo$').hasMatch(path)) {
      return http.StreamedResponse(
        Stream.value(_documentoDemonstracao()),
        200,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition':
              'inline; filename="documento-demonstracao.pdf"',
        },
        request: request,
      );
    }
    if (request.method == 'GET' && path == '/profissionais/me/agenda') {
      final mes =
          DateTime.tryParse('${request.url.queryParameters['mes']}-01') ??
          DateTime.now();
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'atendimentos': [
                {
                  ...pedidos[1],
                  'dataServico': DateTime(
                    mes.year,
                    mes.month,
                    16,
                  ).toIso8601String().substring(0, 10),
                },
              ],
              'disponibilidade': [
                for (final dia in [1, 3, 5])
                  {
                    'diaSemana': dia,
                    'horaInicio': '08:00',
                    'horaFim': '18:00',
                    'ativo': true,
                  },
              ],
            }),
          ),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: request,
      );
    }
    return super.send(request);
  }
}

Uint8List _documentoDemonstracao() {
  // PDF local de uma página, sem identidade ou documento pessoal.
  const desenho = '''
0.945 0.973 0.953 rg
0 700 595 142 re f
0.082 0.478 0.329 rg
BT /F1 26 Tf 42 775 Td (ConectaLar) Tj ET
BT /F1 18 Tf 42 739 Td (Documento de demonstração) Tj ET
0.082 0.231 0.192 rg
BT /F1 14 Tf 42 656 Td (Arquivo fictício para conferência visual.) Tj ET
BT /F1 14 Tf 42 625 Td (Não contém informações de uma pessoa real.) Tj ET
0.890 0.922 0.902 RG
42 375 511 200 re S
BT /F1 22 Tf 73 530 Td (DEMO) Tj ET
BT /F1 14 Tf 73 487 Td (Tipo: documento de identificação fictício) Tj ET
BT /F1 14 Tf 73 451 Td (Uso: prévia do aplicativo) Tj ET
BT /F1 14 Tf 73 415 Td (Decisões nesta galeria não são gravadas.) Tj ET
BT /F1 12 Tf 42 50 Td (ConectaLar - galeria visual) Tj ET
''';
  final objetos = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding >>',
    '<< /Length ${latin1.encode(desenho).length} >>\nstream\n${desenho}endstream',
  ];
  final arquivo = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objetos.length; i++) {
    offsets.add(arquivo.length);
    arquivo.write('${i + 1} 0 obj\n${objetos[i]}\nendobj\n');
  }
  final inicioXref = arquivo.length;
  arquivo.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    arquivo.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  arquivo.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
    'startxref\n$inicioXref\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(arquivo.toString()));
}
