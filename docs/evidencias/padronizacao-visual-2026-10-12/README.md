# Parte 1 — espaçamentos e formas

Data: 12/10/2026. Base: `a9d2d85`, recebida com `git pull origin main` antes das alterações.

## Escopo

Primeira parte do acabamento visual solicitado: estabelecer uma base comum de espaçamentos, bordas e cantos arredondados, preservando as cores oficiais. Referências: padrão visual de `Prototipo 2.pdf` (principalmente Busca e Favoritos) e telas profissionais de `ConectaLar_Telas_Individuais_Cliente_Profissional.pdf`.

## O que mudou

- A escala existente de 4, 8, 12, 16, 24 e 32 px passou a orientar os intervalos dos componentes revisados. A margem lateral móvel continua em 20 px.
- `AppInsets.page` e `AppInsets.card` centralizam os recuos de páginas e cards. Os cards de profissionais agora têm os mesmos 16 px internos dos cards de avaliações e de conteúdo.
- Campos e botões de texto/contorno compartilham o raio de 14 px. Cards mantêm 18 px; diálogos e a parte superior dos painéis inferiores usam 22 px. Chips e selos usam formato de cápsula.
- Busca: campos herdam as bordas do tema; filtros e estado vazio usam a cor de borda já existente; espaçamentos de seções, chips e resultados seguem a escala.
- Favoritos: margens e intervalos alinhados à Busca; selo e card compartilhado seguem o padrão.
- Disponibilidade: margens, cards de horários e formulário inferior alinhados ao padrão. O espaço inferior para o botão flutuante permanece reservado.
- Estados compartilhados de erro e vazio usam a mesma escala de espaçamento e conservam a rolagem.

O tema também se aplica aos controles das telas profissionais e administrativas que o herdam. Componentes com decoração própria, como o cabeçalho da Home e os blocos do perfil público, continuam para as próximas partes da revisão visual.

## Preservação e verificações

- A definição completa de `AppColors` foi comparada com a base e está idêntica. Nenhum valor literal de cor dos sete arquivos Flutter alterados foi modificado.
- Não houve edição de backend, serviços, modelos, rotas, validações ou dos arquivos reservados pelo colega. Textos, callbacks e condições de negócio foram preservados; a mudança é de apresentação.
- `dart format`: aplicado aos sete arquivos Flutter alterados.
- `flutter analyze`: aprovado, sem problemas.
- `flutter test --concurrency=2 --reporter expanded`: 91 testes aprovados, em 2 min 17 s.
- A suíte inclui Busca, Favoritos, cards profissionais e Disponibilidade em 360, 390 e 412 px, com texto até 200%, callbacks e espaço de teclado simulado. Também inclui testes de telas profissionais e módulos administrativos afetados pelo tema.

Esses testes usam dados controlados. Eles não substituem a homologação em aparelho físico com API real e teclado nativo.

## Capturas conferidas

Prévia identificada como DEMONSTRAÇÃO, executada em Flutter Web debug no Chrome headless. Quinze capturas com texto em escala normal foram inspecionadas: cards, campos, selos e ações visíveis permaneceram legíveis nas três larguras. O formato em cápsula dos filtros e as bordas dos blocos da Busca podem ser comparados com a [captura anterior de 360 px](../cards-profissionais-2026-10-11/busca-360.png).

| Tela/estado | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Busca preenchida | [Captura](busca-360.png) | [Captura](busca-390.png) | [Captura](busca-412.png) |
| Busca vazia, campo em foco | [Captura](busca-vazia-360.png) | [Captura](busca-vazia-390.png) | [Captura](busca-vazia-412.png) |
| Favoritos | [Captura](favoritos-360.png) | [Captura](favoritos-390.png) | [Captura](favoritos-412.png) |
| Disponibilidade | [Captura](disponibilidade-360.png) | [Captura](disponibilidade-390.png) | [Captura](disponibilidade-412.png) |
| Formulário de horário, viewport reduzido | [Captura](disponibilidade-modal-viewport-reduzido-360.png) | [Captura](disponibilidade-modal-viewport-reduzido-390.png) | [Captura](disponibilidade-modal-viewport-reduzido-412.png) |

A altura é de 844 px nas telas e 484 px no formulário com campo em foco. O viewport reduzido não é uma captura de teclado nativo. A ampliação de texto até 200% foi verificada pelos testes Flutter descritos acima, não pelas imagens.

As duas compilações web de demonstração (cliente e profissional) passaram. As cinco execuções no navegador registraram zero exceções e zero erros de console; avisos de viewport e GPU estão descritos no [resumo do navegador](resumo-navegador.json).

Comandos de compilação utilizados:

```bash
flutter build web --debug --no-pub --dart-define=CONECTALAR_DEMO=true --output=/tmp/conectalar-estilo-parte1-cliente
flutter build web --debug --no-pub --no-wasm-dry-run --dart-define=CONECTALAR_DEMO=true --dart-define=CONECTALAR_DEMO_ROLE=profissional --output=/tmp/conectalar-estilo-parte1-profissional
```

Próxima parte planejada: hierarquia dos textos, usando a mesma paleta e respeitando os arquivos reservados pela equipe.
