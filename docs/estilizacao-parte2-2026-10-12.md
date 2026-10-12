# Parte 2 — hierarquia dos textos

Base: `0e8571d`. Data: 12/10/2026.

- O tema passou a definir explicitamente títulos, corpo, legendas e rótulos, com alturas de linha consistentes.
- Títulos de página usam 20 px; títulos de cards, 16 px; corpo, 14 px; metadados, 12 px. Os selos compactos passaram de 10 para 11 px e as etiquetas de serviços de 10 para 12 px.
- Favoritos e os cards de profissionais/avaliações usam os papéis tipográficos do tema. Preços e nomes têm mais destaque que informações auxiliares.
- A navegação inferior passou a usar rótulos de 11 px e altura de 72 px, preservando ícones, destinos e callbacks.
- `AppColors` foi comparado com a base: definição integralmente preservada. Não houve alteração de backend, rotas ou regras de negócio.

## Verificação

- `dart format`: aplicado aos quatro arquivos Flutter alterados.
- `flutter analyze`: sem problemas.
- `flutter test --no-pub --concurrency=2 --reporter expanded`: 91 testes aprovados em 2 min 35 s, saída 0. Uma execução anterior também registrou 91 aprovações, mas terminou com sinal de interrupção; por isso houve uma segunda execução completa.
- A suíte inclui cenários em 360, 390 e 412 px, cards com conteúdo longo, texto até 200%, ações acessíveis e espaço de teclado simulado. Esses testes usam dados controlados e não representam homologação em aparelho real.

A inspeção das capturas com o conjunto das partes 2 a 4 será registrada ao concluir a parte 4.
