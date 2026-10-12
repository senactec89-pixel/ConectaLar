# Home responsiva — 11/10/2026

Referência: primeira tela de `Prototipo 2.pdf` e capturas [anteriores da Home](../front-end-2026-10-11/README.md). A revisão manteve a paleta oficial, a imagem da casa, seu recorte circular, enquadramento e posição à direita. Com texto padrão, a altura do cabeçalho continua em 306 px.

## Ajustes

- A categoria **Ar-condicionado** aparecia cortada em largura mobile. A grade usa três colunas nessas larguras e duas com texto ampliado, preservando rótulos completos e a área de toque de cada categoria.
- O coração nos cards de destaque e os links **Ver todas** têm alvo mínimo de 48 px. A mesma ação e navegação permanecem conectadas.
- Com texto acima de 150%, o cabeçalho cresce conforme o conteúdo. A saudação e o texto de apoio ficam inteiros, com a busca abaixo deles. Os cards de destaque passam a uma coluna para evitar overflow.

## Capturas mobile

As imagens vêm da prévia Flutter Web, com dados fictícios, texto padrão, viewport de 844 px e escala de dispositivo 1. O segundo conjunto registra a seção de profissionais após rolar pela interface.

| Área | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Home | [Captura](home-360.png) | [Captura](home-390.png) | [Captura](home-412.png) |
| Profissionais em destaque | [Captura](home-cards-360.png) | [Captura](home-cards-390.png) | [Captura](home-cards-412.png) |

As seis imagens medem 360/390/412 × 844 px. O percurso teve zero exceções de execução e zero erros de console; foram registrados cinco avisos de viewport e GPU, resumidos em [resumo-navegador.json](resumo-navegador.json). A prévia mostra o ícone de foto ausente porque os dados servidos nesse modo não trazem imagem para esses cards; isso não foi tratado como foto real.

## Verificação

- Teste de widget em 360, 390 e 412 px, com texto a 100% e 200%: rótulos inteiros, saudação acima da busca, áreas de toque de 48 px e ausência de overflow.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --concurrency=2`: 87 testes aprovados.
- Compilação web da prévia de cliente: aprovada.
- Comparação do arquivo antes/depois: os literais de cor e referências a `AppColors` são os mesmos; arquivo, `BoxFit.cover` e `Alignment(0.65, 0)` da casa permanecem iguais.

O texto a 200% foi conferido nos testes de widgets. As capturas foram feitas com texto padrão; não substituem a conferência com API real e aparelho físico.
