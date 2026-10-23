# Aplicação da nova marca ConectaLar

As capturas foram feitas em 23/10/2026 no preview Flutter Web em modo demonstração. Elas não usam API nem dados reais.

## Alterações visuais

- O símbolo de casa conectada da referência foi redesenhado em SVG plano usando os verdes oficiais já definidos em `lib/app/theme.dart`.
- O wordmark “ConectaLar” usa texto Flutter, com “Conecta” em verde escuro e “Lar” em verde, para continuar legível com leitor de tela e texto ampliado.
- A marca aparece no cabeçalho da Home e na tela de login. O símbolo também foi exportado para os ícones e as telas de abertura das plataformas configuradas no projeto.
- Na Home, o tamanho base do wordmark se ajusta quando a preferência de texto está ampliada, para manter o nome em uma linha e não sobrepor o círculo da casa.

## Conferência

As capturas cobrem Home e login em 360, 390 e 412 px, em escala de texto normal e a 200%. A lista está em `capturas.json`; o campo `excecoesNavegador` ficou vazio.

O texto a 200% amplia outros componentes da Home e pode exigir rolagem adicional; este ajuste preserva a leitura da marca e não altera essa estrutura existente.

Validações executadas:

- `flutter analyze --no-pub`: sem problemas.
- Preview de demonstração compilado para Web.
- APK Android debug compilado para conferir os recursos nativos da marca.

Os dados exibidos no preview são fictícios. Esta evidência verifica apresentação visual, não os fluxos ligados à API.
