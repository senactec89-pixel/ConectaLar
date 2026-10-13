# Evidências da estilização — 13/10/2026

Capturas do Flutter Web em 360, 390 e 412 pixels lógicos, altura de 844 px e DPR 1. `-200` indica fonte a 200%. A faixa **DEMO** identifica dados fictícios fornecidos por `FrontendPreviewClient`; nenhuma operação é gravada na API real.

| Tela ou estado | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Home | [Imagem](home-360.png) | [Imagem](home-390.png) | [Imagem](home-412.png) |
| Home, fonte 200% | [Imagem](home-200-360.png) | [Imagem](home-200-390.png) | [Imagem](home-200-412.png) |
| Busca | [Imagem](busca-360.png) | [Imagem](busca-390.png) | [Imagem](busca-412.png) |
| Formulário de categoria | [Imagem](categoria-360.png) | [Imagem](categoria-390.png) | [Imagem](categoria-412.png) |
| Formulário de categoria, fonte 200% | [Imagem](categoria-200-360.png) | [Imagem](categoria-200-390.png) | [Imagem](categoria-200-412.png) |
| Histórico administrativo | [Imagem](historico-360.png) | [Imagem](historico-390.png) | [Imagem](historico-412.png) |
| Histórico administrativo, fonte 200% | [Imagem](historico-200-360.png) | [Imagem](historico-200-390.png) | [Imagem](historico-200-412.png) |
| Documentos do profissional | [Imagem](documentos-360.png) | [Imagem](documentos-390.png) | [Imagem](documentos-412.png) |
| Lista de moderação documental | [Imagem](admin-documentos-360.png) | [Imagem](admin-documentos-390.png) | [Imagem](admin-documentos-412.png) |
| Diálogo de análise documental | [Imagem](admin-documentos-modal-360.png) | [Imagem](admin-documentos-modal-390.png) | [Imagem](admin-documentos-modal-412.png) |
| Lista de denúncias | [Imagem](admin-denuncias-360.png) | [Imagem](admin-denuncias-390.png) | [Imagem](admin-denuncias-412.png) |
| Diálogo de denúncia | [Imagem](admin-denuncias-modal-360.png) | [Imagem](admin-denuncias-modal-390.png) | [Imagem](admin-denuncias-modal-412.png) |
| Lista de avaliações | [Imagem](admin-avaliacoes-360.png) | [Imagem](admin-avaliacoes-390.png) | [Imagem](admin-avaliacoes-412.png) |
| Diálogo de avaliação | [Imagem](admin-avaliacoes-modal-360.png) | [Imagem](admin-avaliacoes-modal-390.png) | [Imagem](admin-avaliacoes-modal-412.png) |
| Lista de categorias | [Imagem](admin-categorias-360.png) | [Imagem](admin-categorias-390.png) | [Imagem](admin-categorias-412.png) |

As 45 imagens são da primeira área visível de cada tela. A galeria executada é [`tool/preview_estilizacao.dart`](../../../tool/preview_estilizacao.dart). O script [`tool/capture_visual.ps1`](../../../tool/capture_visual.ps1) aplica as dimensões via Chrome DevTools Protocol, evitando a largura mínima da janela headless. Para reproduzir:

1. Compile a galeria: `flutter build web --debug --no-pub --no-wasm-dry-run --no-web-resources-cdn --target=tool/preview_estilizacao.dart --dart-define=CONECTALAR_DEMO=true`.
2. Sirva `build/web` em `http://127.0.0.1:8765/` e inicie o Chrome headless com depuração remota em `127.0.0.1:9222`.
3. Execute `tool/capture_visual.ps1` no PowerShell. O script aceita `-Scenes`, `-Widths`, `-WaitSeconds`, `-BaseUrl` e `-DebugPort`.

Os estados de envio e erro do formulário de categoria são verificados em [`test/admin_categoria_form_test.dart`](../../../test/admin_categoria_form_test.dart); a prévia recusa mutações, então estas capturas não demonstram salvamento real. Os testes de widgets cobrem rolagem, toque, fonte a 200% e teclado simulado, mas as imagens Web não comprovam teclado nativo, TalkBack ou integração Flutter/API em Android.
