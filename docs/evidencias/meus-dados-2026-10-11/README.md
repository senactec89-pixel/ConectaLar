# Meus dados e estados comuns — 11/10/2026

Referência: telas de perfil e formulários de `Prototipo 2.pdf` e `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf`. A tela conserva os campos, validações e envio existentes.

## Ajuste

- O texto de apoio do e-mail passa a quebrar em várias linhas. Em 360, 390 e 412 px com texto a 200%, ele fica inteiro e o botão de salvar continua alcançável com 300 px de espaço reservado ao teclado.
- Os estados de carregamento e erro de **Meus dados** usam os componentes visuais comuns do app. O erro fica rolável em altura reduzida e mantém **Tentar novamente**.
- O botão de nova tentativa do componente comum tem alvo mínimo de 48 px. As cores continuam sendo as do tema existente.

## Capturas mobile

Prévia Flutter Web com dados fictícios, texto padrão, viewport de 844 px e escala de dispositivo 1:

| 360 px | 390 px | 412 px |
| --- | --- | --- |
| [Captura](editar-dados-360.png) | [Captura](editar-dados-390.png) | [Captura](editar-dados-412.png) |

O percurso Perfil → Meus dados teve zero exceções de execução e zero erros de console. Os cinco avisos do navegador sobre viewport e GPU estão resumidos em [resumo-navegador.json](resumo-navegador.json).

## Verificação

- Testes específicos: texto de apoio inteiro nas três larguras a 200%, formulário acessível com espaço de teclado, estado de erro em 360 × 220 px a 200% e botão de nova tentativa com 48 px.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --concurrency=2`: 89 testes aprovados.
- Compilação web da prévia de cliente: aprovada.

O espaço reservado nos testes representa a redução de área pelo teclado; não é um teclado nativo. A prévia não comprova o salvamento com a API real.
