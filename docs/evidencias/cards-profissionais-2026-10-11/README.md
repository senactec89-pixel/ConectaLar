# Cards de profissionais — 11/10/2026

Referências: cards da Busca em `Prototipo 2.pdf`, telas individuais de cliente e as capturas anteriores de [Busca](../busca-profissional-2026-10-11/README.md) e [Favoritos](../acabamento-isolado-2026-10-11/README.md).

## Ajuste

O teste anterior da Busca preenchida, em 360 px com texto a 200%, encontrava dois overflows: 30 px no selo de verificação e 29 px na linha de preço e ações. O card agora deixa selo, avaliação, bairro, descrição, serviços e preço crescerem com o texto. Quando necessário, o preço fica acima das ações. O botão **Ver perfil** tem altura mínima de 48 px. Nome, descrição e serviços mantêm o comportamento compacto com texto padrão.

A foto preserva tamanho, enquadramento e recorte; as cores e os dados exibidos continuam iguais. Permanecem os três serviços visíveis e os mesmos callbacks do card, do botão de perfil e do favorito.

## Capturas mobile

As imagens foram capturadas no Flutter Web com texto padrão, viewport de 844 px de altura e escala de dispositivo 1. A prévia usa dados fictícios claramente identificados na interface. Não representam uma consulta à API real.

| Tela | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Busca | [Captura](busca-360.png) | [Captura](busca-390.png) | [Captura](busca-412.png) |
| Busca com Elétrica | [Captura](busca-categoria-360.png) | [Captura](busca-categoria-390.png) | [Captura](busca-categoria-412.png) |
| Favoritos | [Captura](favoritos-360.png) | [Captura](favoritos-390.png) | [Captura](favoritos-412.png) |

As nove imagens medem 360/390/412 × 844 px. Os três percursos tiveram zero exceções de execução e zero erros de console. Cada percurso registrou cinco avisos do navegador sobre viewport e GPU; a contagem está em [resumo-navegador.json](resumo-navegador.json).

## Verificação

- Testes de Busca e Favoritos preenchidos passaram com texto a 200%, incluindo filtros, remoção de favorito e navegação.
- Testes isolados do card passaram em 360, 390 e 412 px, nas escalas de texto 100%, 140% e 200%, com nomes, bairros, avaliações, serviços e preços longos. Também verificaram foto, ausência de dados, alvo de toque e callbacks.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --concurrency=2`: 86 testes aprovados, após integrar os commits remotos até `6753252`.
- `flutter build web --debug --no-pub --no-wasm-dry-run --no-web-resources-cdn` com prévia de cliente: aprovado.

O texto a 200% foi verificado nos testes de widgets; as capturas usam texto padrão. O teclado nativo e o fluxo com a API real dependem de homologação em aparelho.
