# Busca — composição visual, etapa 1

Data: 11/10/2026. Base: `5db8ecb`, atualizada com `git pull origin main` antes da edição. Referência visual: página 2 de `Prototipo 2.pdf`.

## Ajustes

- O título principal permanece na barra superior. A orientação aparece diretamente acima dos campos, liberando espaço para resultados.
- Espaçamentos verticais menores entre orientação, filtros e lista, sem fixar a altura dos campos ou limitar a ampliação do texto.
- “Limpar filtros” aparece somente quando existe um filtro ativo.
- Categoria selecionada e limpeza compartilham a linha quando há espaço; o resumo permite quebra e preserva o nome completo.
- A ação de limpar mantém altura mínima de 48 px.

As cores literais da Busca foram comparadas com a base e permaneceram iguais. O tema, o card compartilhado, os serviços e as rotas permaneceram idênticos. Os métodos de carregar, filtrar, selecionar categoria, limpar, abrir perfil e normalizar texto não foram alterados.

## Capturas de demonstração

Flutter Web em Chrome headless, altura 844 px lógicos e escala de dispositivo 1. Os dados são fictícios e a identificação DEMONSTRAÇÃO permanece visível. As capturas não validam o fluxo com a API real nem representam teclado nativo.

| Estado | 360 px | 390 px | 412 px |
| --- | --- | --- | --- |
| Sem filtros | [Captura](busca-360.png) | [Captura](busca-390.png) | [Captura](busca-412.png) |
| Categoria Elétrica | [Captura](busca-categoria-360.png) | [Captura](busca-categoria-390.png) | [Captura](busca-categoria-412.png) |
| Busca sem resultado | [Captura](busca-vazia-360.png) | [Captura](busca-vazia-390.png) | [Captura](busca-vazia-412.png) |

Comparação anterior: [sem filtros em 360 px](../acabamento-isolado-2026-10-11/busca-360.png) e [categoria em 390 px](../acabamento-isolado-2026-10-11/busca-categoria-390.png).

## Verificações

- Testes específicos: seis aprovados, nas larguras 360, 390 e 412 px.
- Cobertura nova: resultados mais cedo, ausência de limpeza desativada, ação de 48 px, limpeza com retorno da lista, categoria longa com texto 200% e espaço de teclado de 300 px.
- Cobertura anterior mantida: lista preenchida em 140%, filtro por bairro, categorias no fim da faixa, estado vazio em 200% e categoria recebida da Home.
- `flutter analyze --no-pub`: aprovado, sem problemas.
- `flutter test --no-pub --concurrency=2`: suíte completa aprovada, 84 testes (1 min 49 s).
- Compilação debug web: aprovada (92,2 s). Nove capturas concluídas com zero exceções de execução e zero erros de console. Avisos de viewport e GPU resumidos em `resumo-navegador.json`.

O teste com fonte ampliada usa as métricas do ambiente de testes Flutter. A posição dos resultados nele não representa a mesma medida das capturas em Chrome.

## Próxima etapa

O `ProfissionalCard` ainda tem os cortes previamente documentados com texto 200%. Os testes preenchidos desta etapa cobrem 140%; a categoria longa e o estado vazio cobrem 200%. A revisão do componente compartilhado continua dependendo da divisão de arquivos com a equipe.
