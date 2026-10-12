# Perfil público do profissional — 11/10/2026

Referência: tela C03 de `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf`. A revisão concentra foto, nome, descrição, avaliação, verificação documental e ação de solicitar em uma hierarquia legível.

## Ajuste

Um teste com nome longo e selo em 360 px encontrou overflows horizontais de 19 e 166 px. Avaliação e selo agora ocupam uma linha própria, com quebra de texto quando necessário. Com texto acima de 150%, nome e descrição também usam a largura completa abaixo da foto. A ação de favorito e o botão de solicitação conservam seus callbacks e rotas.

As cores, a condição do selo, a foto recebida, o preço e os serviços exibidos não foram alterados. A prévia abaixo recebe profissionais sem foto; por isso mostra o avatar de ausência de imagem. A foto grande ilustrada no protótipo não é inferida pela UI quando os dados não a trazem.

## Capturas mobile

Prévia Flutter Web com dados fictícios, texto padrão, viewport de 844 px e escala de dispositivo 1:

| 360 px | 390 px | 412 px |
| --- | --- | --- |
| [Captura](perfil-publico-360.png) | [Captura](perfil-publico-390.png) | [Captura](perfil-publico-412.png) |

O percurso Busca → Ver perfil teve zero exceções de execução e zero erros de console. Os cinco avisos de viewport e GPU estão resumidos em [resumo-navegador.json](resumo-navegador.json).

## Verificação

- Teste específico em 360, 390 e 412 px, texto a 100%, 140% e 200%, com nome, descrição e contagem de avaliações longos: sem overflow; selo inteiro; favorito e solicitação com alvo de pelo menos 48 px.
- Teste de navegação existente confirma a seção **Antes de solicitar** após rolar e a abertura do formulário.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --concurrency=2`: 90 testes aprovados.
- Compilação web da prévia de cliente: aprovada.

As capturas usam texto padrão e dados fictícios. O texto ampliado foi conferido nos testes de widgets; o fluxo completo com API real continua no roteiro de homologação.
