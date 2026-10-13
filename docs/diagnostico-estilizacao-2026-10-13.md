# Diagnóstico da estilização do ConectaLar

Data: 13/10/2026. Base revisada: `main` em `048abb9`, com alterações locais de dependências já existentes. Escopo: apresentação Flutter, componentes, testes de interface, capturas e referências visuais. As capturas disponíveis usam dados de demonstração; não representam homologação em aparelho.

## O que já está entregue

- `lib/app/theme.dart` centraliza paleta, espaçamento, tipografia, bordas, botões, diálogos e navegação. Busca, favoritos, formulários e estados de carregamento/erro/vazio compartilham esses padrões.
- Home, Busca, Favoritos, perfil público, documentos, disponibilidade e painel administrativo têm evidências de largura móvel em 360, 390 e 412 px. Há testes de widgets com texto ampliado e teclado simulado para áreas específicas.
- A tela `lib/screens/admin/categoria_form_page.dart` já tem nome, seleção de ícone, status e prévia com testes em três larguras e texto a 200%. Não aparece entre as falhas da execução completa anterior.
- Os seis pares principais de texto/fundo registrados em `docs/evidencias/estilizacao-parte6-2026-10-12/README.md` passaram no teste de contraste. Isso não cobre todos os estados e componentes.

## Trabalho recomendado para a parte visual

| Prioridade | Área | Evidência atual | Próxima ação |
| --- | --- | --- | --- |
| Alta | Home, grade de categorias | `test/home_visual_test.dart` falhou em 360 px, texto 100%: o rótulo “Ar-condicionado” excede o limite de linhas. `_CategoryTile` em `lib/screens/home/home_page.dart` usa grade de 3 colunas, altura fixa de 84 px e `TextOverflow.ellipsis`. | Ajustar colunas/altura e quebra de linha conforme a largura e o nome; garantir que categorias reais não fiquem cortadas. Repetir em 360/390/412 px e texto 100/200%. |
| Alta | Testes visuais | Seis das nove falhas anteriores aparecem em `find.widgetWithText(TextButton/FilledButton, ...)` aplicado a botões `.icon`. O Flutter instalado usa subclasses nesses casos, e `find.byType` faz comparação exata. | Usar seletores por chave/rótulo e tipo apropriado; verificar novamente tamanho, toque e resultado da ação. Não alterar os botões apenas para satisfazer o seletor. |
| Alta | Busca e histórico administrativo | O teste de categoria longa usa `ensureVisible`, mas o finder não encontra o texto; a montagem tardia pela `ListView` é uma hipótese a conferir. O teste de histórico acusa `Build scheduled during frame` com teclado/texto a 200%. | Revisar rolagem e sincronização dos testes; depois reproduzir o histórico em largura e altura reduzidas para confirmar se há defeito na tela. |
| Média | Evidências visuais atuais | Capturas de Home e documentos refletem versões anteriores: a grade e o rótulo documental vistos nas imagens não correspondem ao código atual. | Regerar capturas por commit, largura e escala. Incluir `categoria_form_page.dart`, histórico administrativo, listas/modais de moderação e estados de salvamento. |
| Média | Validação em aparelho | `docs/homologacao-visual.md` permanece sem marcação de execução real. Capturas Web e testes simulam teclado, seletor e serviços. | Verificar Android real com API de teste: teclado nativo, navegação, fonte ampliada, orientação prevista, TalkBack, foco, estados de carregamento/erro/vazio e arquivos. Registrar capturas sem dados privados. |
| Baixa | Polimento da Busca | A faixa horizontal de categorias corta parcialmente o próximo chip na borda, embora haja instrução “Deslize para ver mais”. | Conferir se a pista de rolagem é clara em aparelho; considerar reforçar a indicação visual sem reduzir a área de toque ou ocultar o filtro ativo. |

## O que depende de outras frentes

- O botão para inspecionar o conteúdo de documento administrativo depende de uma rota de leitura autorizada na API. A interface atual mostra metadados; não deve simular aprovação visual de arquivo não aberto.
- Login Google depende de contrato e configuração OAuth, além de P01/P02/P16. Não é pendência de acabamento visual isolado.
- Campos, políticas e ações sugeridos nos protótipos administrativo e principal são referências; mudanças de permissões, documentos exigidos e comportamento central exigem decisão de produto.

## Resultado dos checks já disponíveis

Na verificação anterior desta conversa, `flutter analyze --no-pub` terminou sem problemas e `flutter test --no-pub` teve 137 aprovações e 9 falhas no Flutter 3.38.6/Dart 3.10.7. Nenhum arquivo Flutter foi alterado nesta revisão. Corrigir a truncagem comprovada e atualizar os testes são os primeiros passos para estabelecer uma base visual verde; a inspeção em aparelho fecha a validação da experiência.

## Execução após o diagnóstico

- A grade da Home passou a reservar largura para os nomes das categorias. O cabeçalho de seção, a busca e a imagem da abertura também foram ajustados para fonte a 200%. O teste verifica 360, 390 e 412 px em escalas 100% e 200%, sem truncar “Ar-condicionado” nem o título “Categorias de serviços”.
- Os seletores de botões com ícone foram corrigidos sem alterar os botões de produção. O teste de Busca passou a rolar até a categoria longa. No histórico, o foco é estabelecido antes de ampliar a fonte no ambiente de teste; a combinação final de fonte a 200% e teclado simulado continua verificada. O foco diretamente com a fonte a 200% ainda exige conferência em Android real.
- A suíte completa passou com **146 testes**, e `flutter analyze --no-pub` não apontou problemas na execução da etapa de testes. A [nova galeria de 45 capturas](evidencias/estilizacao-2026-10-13/README.md) inclui Home, Busca, categoria, histórico, documentos, listas administrativas e diálogos em três larguras, além de Home, categoria e histórico com fonte a 200%.
- A faixa de categorias da Busca foi conferida nas três larguras. O próximo filtro permanece parcialmente visível e o texto “Deslize para ver mais →” identifica a rolagem horizontal; não houve necessidade de mudança adicional.
- `flutter devices` detectou Windows, Chrome e Edge, mas nenhum Android. As tarefas de teclado nativo, TalkBack e API de teste continuam sem homologação; o [roteiro visual](homologacao-visual.md) permanece desmarcado até execução em aparelho.
