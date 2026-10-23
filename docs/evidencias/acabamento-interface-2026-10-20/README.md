# Acabamento da interface — 20/10/2026

Conferência em **Flutter Web, com dados fictícios da galeria de demonstração**.
Esta evidência visual não representa homologação em Android físico, TalkBack ou API real.

## Melhorias entregues

1. **Legibilidade:** rótulos pequenos passaram a usar 12 px como tamanho base. A navegação oferece rolagem com indicador visível quando o texto ampliado exige mais espaço, mantendo os rótulos, a seleção, as descrições e as ações. O limite administrativo de 110% foi removido.
2. **Perfil público:** preço inicial e quantidade de serviços compartilham um resumo compacto. O conteúdo se reorganiza verticalmente com texto ampliado. Foto, atalhos, informações e botão de atendimento foram preservados.
3. **Cartões de profissionais:** quantidade de avaliações explícita, com singular/plural; avaliação e localização ganham a largura do cartão com texto ampliado. O selo permanece junto à foto. Preço e ações ficam lado a lado quando cabem e se reorganizam quando necessário.
4. **Documentos administrativos:** filtros organizados em grupos equilibrados de quatro, dois ou um por linha, conforme a largura disponível e o texto. Botões de visualização e análise com a mesma largura e altura mínima de 52 px, lado a lado ou empilhados.

## Verificações

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: **217 testes aprovados**.
- Build web de demonstração concluído.
- Matriz visual: **360, 390 e 412 pixels lógicos**, texto em **100% e 200%**, nas telas Home, perfil público, Busca, documentos administrativos e agenda.
- Coleta da matriz: **90 capturas, sem exceções registradas pelo navegador**. Doze imagens foram selecionadas para este registro.
- Navegação também verificada por teste de widget com texto em 130% e 300%.
- Os testes preservam consultas e ações existentes: filtros documentais, acesso privado ao arquivo, validação da rejeição, favoritos, comparação e solicitação a partir do perfil.
- Valores de cor do tema comparados com a versão anterior e preservados. Nenhuma alteração em backend, contratos, serviços de API ou rotas.

## Capturas selecionadas

Os arquivos e as dimensões das capturas selecionadas estão em `capturas.json`.
As capturas de conteúdo e final mostram áreas alcançadas por rolagem; não são imagens da tela inteira em uma única posição.

| Tela | Texto normal | Texto ampliado |
| --- | --- | --- |
| Home | [360 px](home-360.png) | [Categorias, 390 px](home-200-conteudo-390.png) |
| Perfil público | [360 px](perfil-publico-360.png) | [Resumo, 390 px](perfil-publico-200-conteudo-390.png) |
| Busca | [Cartões, 390 px](busca-conteudo-390.png) | [Cartão, 390 px](busca-200-conteudo-390.png) |
| Documentos | [360 px](admin-documentos-360.png), [390 px](admin-documentos-390.png), [412 px](admin-documentos-412.png) | [Filtros, 390 px](admin-documentos-200-390.png), [Ações, 390 px](admin-documentos-200-final-390.png) |
| Agenda | — | [Navegação, 390 px](agenda-200-390.png) |
