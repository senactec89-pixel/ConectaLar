import 'package:conectarlar_app/services/api_service.dart';
import 'package:conectarlar_app/services/service_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/visual_preview_client.dart';

void main() {
  test('galeria mostra profissionais da região no conteúdo inicial', () async {
    final services = AppServices(
      modoDemo: true,
      api: ApiService(client: VisualPreviewClient(papel: 'cliente')),
    );
    addTearDown(services.api.close);
    await services.inicializar();
    final home = await services.carregarHome();
    expect(home.professionalsLoadFailed, isFalse);
    expect(home.regionalAddressUnavailable, isFalse);
    expect(
      home.featuredProfessionals.map((profissional) => profissional.nome),
      ['Carlos Silva', 'Ana Souza'],
    );
  });
}
